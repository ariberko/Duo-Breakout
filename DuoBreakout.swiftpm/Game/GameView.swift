import SwiftUI

/// The whole game screen. Works on the small closed screen, in tent mode and on the big open screen.
struct GameView: View {
    @StateObject private var engine = GameEngine()
    @EnvironmentObject private var store: Store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("skin") private var skinID = Skin.neon.id
    @State private var showingShop = false

    /// The chosen skin, or Neon if it isn't owned (for example after a refund).
    private var skin: Skin {
        let chosen = Skin.with(id: skinID)
        return store.owns(chosen) ? chosen : .neon
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: skin.background, startPoint: .top, endPoint: .bottom)

                if engine.phase != .menu {
                    board
                    TouchPad(engine: engine)
                    hud
                }

                overlay(posture: Posture(size: geo.size))
            }
            .onAppear { engine.setLayout(size: geo.size, insets: geo.safeAreaInsets) }
            .onChange(of: geo.size) { _, size in engine.setLayout(size: size, insets: geo.safeAreaInsets) }
            .onChange(of: geo.safeAreaInsets) { _, insets in engine.setLayout(size: geo.size, insets: insets) }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { engine.pause() }
        }
        .sheet(isPresented: $showingShop) {
            ShopView()
        }
    }

    // MARK: - Drawing

    private var board: some View {
        let skin = skin
        return Canvas { context, size in
            if skin.stars {
                for star in StarField.stars {
                    context.fill(Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height,
                                                        width: star.size, height: star.size)),
                                 with: .color(.white.opacity(0.6)))
                }
            }
            if engine.mode == .duo {
                // Each half is tinted in its player's color.
                context.fill(Path(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2)),
                             with: .color(skin.players[0].opacity(0.06)))
                context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)),
                             with: .color(skin.players[1].opacity(0.06)))
            } else {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: engine.soloTopWall))
                line.addLine(to: CGPoint(x: size.width, y: engine.soloTopWall))
                context.stroke(line, with: .color(.white.opacity(0.12)), lineWidth: 1)
            }

            for brick in engine.bricks where brick.alive {
                let rect = engine.brickRect(brick)
                let shape = Path(roundedRect: rect, cornerRadius: skin.brickCorner)
                if brick.steel {
                    context.fill(shape, with: .linearGradient(
                        Gradient(colors: [Color(white: 0.75), Color(white: 0.4)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                    continue
                }
                let color = skin.bricks[brick.row % skin.bricks.count]
                context.fill(shape, with: .color(color.opacity(brick.hp == 1 ? 0.75 : 1)))
                if brick.hp >= 2 {
                    context.stroke(shape, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                }
                if brick.hp >= 3 {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 2),
                                   with: .color(.white.opacity(0.7)), lineWidth: 1)
                }
            }

            for drop in engine.drops {
                let rect = engine.dropRect(drop)
                context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(drop.kind.color))
                context.draw(Text(drop.kind.label).font(.system(size: 13, weight: .heavy)).foregroundColor(.black),
                             at: CGPoint(x: rect.midX, y: rect.midY))
            }

            context.drawLayer { glow in
                glow.addFilter(.shadow(color: .white.opacity(skin.glow), radius: 8))
                for player in engine.players {
                    let rect = engine.paddleRect(player)
                    let color = skin.players[engine.mode == .duo ? player : 0]
                    glow.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(color))
                }
                let r = engine.ballRadius
                for ball in engine.balls {
                    let color = engine.mode == .duo ? skin.players[ball.owner].opacity(0.4) : .clear
                    let box = CGRect(x: ball.pos.x - r, y: ball.pos.y - r, width: r * 2, height: r * 2)
                    let shape = skin.squareBall ? Path(box) : Path(ellipseIn: box)
                    glow.fill(shape, with: .color(skin.ball))
                    glow.stroke(shape, with: .color(color), lineWidth: 2)
                }
            }
        }
    }

    // MARK: - Score and lives

    @ViewBuilder
    private var hud: some View {
        switch engine.mode {
        case .solo:
            VStack {
                HStack(spacing: 16) {
                    Text("\(engine.score[0])").monospacedDigit()
                    Spacer()
                    Text("LEVEL \(engine.level)").foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(String(repeating: "♥", count: max(engine.lives[0], 0)))
                        .foregroundStyle(PowerKind.life.color)
                    pauseButton
                }
                .font(Theme.title(18))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .padding(.top, engine.insets.top)
                .padding(.leading, engine.insets.leading)
                .padding(.trailing, engine.insets.trailing)
                Spacer()
            }
        case .duo:
            VStack {
                playerBadge(1).rotationEffect(.degrees(180))
                Spacer()
                HStack {
                    pauseButton
                    Spacer()
                }
                .padding(.horizontal, 12)
                Spacer()
                playerBadge(0)
            }
            .padding(.top, max(engine.insets.top, 12))
            .padding(.bottom, max(engine.insets.bottom, 12))
        }
    }

    private func playerBadge(_ player: Int) -> some View {
        HStack(spacing: 12) {
            Text("P\(player + 1)  \(engine.score[player])").monospacedDigit()
            Text(String(repeating: "♥", count: max(engine.lives[player], 0)))
        }
        .font(Theme.title(15))
        .foregroundStyle(skin.players[player])
        .allowsHitTesting(false)
    }

    private var pauseButton: some View {
        Button {
            engine.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.12), in: Circle())
        }
    }

    // MARK: - Menus

    @ViewBuilder
    private func overlay(posture: Posture) -> some View {
        switch engine.phase {
        case .menu:
            MenuView(posture: posture, best: engine.best, openShop: { showingShop = true }) { mode, rule in
                engine.start(mode, rule: rule, levelPack: store.owns(StoreIDs.levels))
            }
        case .paused:
            dim {
                VStack(spacing: 18) {
                    Text("PAUSED").font(Theme.title(40)).foregroundStyle(.white)
                    NeonButton(title: "RESUME") { engine.resume() }
                    NeonButton(title: "MENU", color: .white.opacity(0.8), small: true) { engine.quitToMenu() }
                }
            }
        case .levelCleared:
            Text("LEVEL \(engine.level)")
                .font(Theme.title(48))
                .foregroundStyle(Theme.players[0])
                .shadow(color: Theme.players[0], radius: 16)
                .allowsHitTesting(false)
        case .over:
            dim { gameOver }
        case .playing:
            if engine.balls.contains(where: { $0.stuckTo != nil }) {
                Text(engine.mode == .duo ? "Drag your paddle - let go to launch" : "Drag to move - let go to launch")
                    .font(Theme.title(15))
                    .foregroundStyle(.white.opacity(0.7))
                    .allowsHitTesting(false)
                    .offset(y: engine.mode == .duo ? engine.size.height * 0.2 : engine.size.height * 0.12)
            }
        }
    }

    @ViewBuilder
    private var gameOver: some View {
        switch engine.mode {
        case .solo:
            VStack(spacing: 14) {
                Text("GAME OVER").font(Theme.title(42)).foregroundStyle(.white)
                Text("Score \(engine.score[0])").font(Theme.title(24)).foregroundStyle(Theme.players[0])
                Text("Best \(engine.best)").font(Theme.title(17)).foregroundStyle(.white.opacity(0.6))
                NeonButton(title: "PLAY AGAIN") { engine.start(.solo, levelPack: store.owns(StoreIDs.levels)) }
                HStack(spacing: 12) {
                    NeonButton(title: "MENU", color: .white.opacity(0.8), small: true) { engine.quitToMenu() }
                    NeonButton(title: "SHOP", color: Skin.gold.bricks[0], small: true) { showingShop = true }
                }
            }
        case .duo:
            VStack(spacing: 20) {
                duoResult(for: 1).rotationEffect(.degrees(180))
                HStack(spacing: 16) {
                    NeonButton(title: "REMATCH", small: true) {
                        engine.start(.duo, rule: engine.rule, levelPack: store.owns(StoreIDs.levels))
                    }
                    NeonButton(title: "MENU", color: .white.opacity(0.8), small: true) { engine.quitToMenu() }
                }
                duoResult(for: 0)
            }
        }
    }

    private func duoResult(for player: Int) -> some View {
        let text: String
        if let winner = engine.winner {
            text = winner == player ? "YOU WIN!" : "YOU LOSE"
        } else {
            text = "DRAW"
        }
        return VStack(spacing: 4) {
            Text(text).font(Theme.title(38))
            Text("\(engine.score[player]) points").font(Theme.title(16)).opacity(0.7)
        }
        .foregroundStyle(skin.players[player])
    }

    private func dim<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.6)
            content()
        }
    }
}
