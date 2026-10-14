import SwiftUI
import UIKit

enum GameMode { case solo, duo }

enum GamePhase { case menu, playing, paused, levelCleared, over }

enum PowerKind: CaseIterable {
    case wide, multi, slow, life

    var label: String {
        switch self {
        case .wide: return "W"
        case .multi: return "3"
        case .slow: return "S"
        case .life: return "♥"
        }
    }

    var color: Color {
        switch self {
        case .wide: return Color(red: 0.3, green: 0.9, blue: 0.4)
        case .multi: return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .slow: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .life: return Color(red: 1.0, green: 0.3, blue: 0.4)
        }
    }

    static func random() -> PowerKind {
        let roll = Int.random(in: 0..<100)
        switch roll {
        case 0..<35: return .wide
        case 35..<65: return .multi
        case 65..<90: return .slow
        default: return .life
        }
    }
}

struct Brick {
    let column: Int
    let row: Int
    var hp: Int
    let steel: Bool

    var alive: Bool { steel || hp > 0 }
}

struct Ball {
    var pos: CGPoint
    var dir: CGVector
    /// Player 0 is the bottom paddle, player 1 is the top paddle (two player game only).
    var owner: Int
    /// The ball rides on this player's paddle until they let go.
    var stuckTo: Int?
    /// Extra balls from the multi-ball power-up. Losing one costs nothing.
    var bonus: Bool
}

struct Drop {
    var pos: CGPoint
    let kind: PowerKind
    /// The player the power-up falls toward.
    let toward: Int
}

/// All the game rules. Positions are in screen points.
@MainActor
final class GameEngine: ObservableObject {
    @Published private(set) var phase: GamePhase = .menu

    private(set) var mode: GameMode = .solo
    private(set) var size: CGSize = .zero
    private(set) var insets = EdgeInsets()
    private(set) var pattern = Levels.solo(level: 1)
    private(set) var bricks: [Brick] = []
    private(set) var balls: [Ball] = []
    private(set) var drops: [Drop] = []
    private(set) var paddleX: [CGFloat] = [0.5, 0.5]
    private(set) var wideTime: [Double] = [0, 0]
    private(set) var slowTime: Double = 0
    private(set) var lives = [3, 3]
    private(set) var score = [0, 0]
    private(set) var level = 1
    private(set) var winner: Int?
    private(set) var best = UserDefaults.standard.integer(forKey: "best")

    /// Ball speed in "long screen sides per second".
    private var speed: CGFloat = 0.6
    private var touchOwner: [ObjectIdentifier: Int] = [:]
    private var touchLastX: [ObjectIdentifier: CGFloat] = [:]
    private var lastTimestamp: CFTimeInterval?
    private lazy var displayLink = DisplayLink { [weak self] timestamp in
        self?.frame(timestamp)
    }

    // MARK: - Layout

    var players: [Int] { mode == .duo ? [0, 1] : [0] }

    var ballRadius: CGFloat { min(max(min(size.width, size.height) * 0.018, 6), 10) }

    private var playLeft: CGFloat { insets.leading }
    private var playRight: CGFloat { size.width - insets.trailing }
    private var playWidth: CGFloat { max(playRight - playLeft, 1) }

    /// The top wall in a one player game. The score bar lives above it.
    var soloTopWall: CGFloat { insets.top + 44 }

    func paddleWidth(_ player: Int) -> CGFloat {
        let base = min(min(size.width, size.height) * (mode == .duo ? 0.22 : 0.26), 190)
        return base * (wideTime[player] > 0 ? 1.6 : 1)
    }

    func paddleRect(_ player: Int) -> CGRect {
        let width = paddleWidth(player)
        let height: CGFloat = 14
        let centerX = playLeft + paddleX[player] * playWidth
        let y: CGFloat
        if player == 0 {
            y = size.height - max(insets.bottom, 12) - 30 - height
        } else {
            y = max(insets.top, 12) + 30
        }
        return CGRect(x: centerX - width / 2, y: y, width: width, height: height)
    }

    func brickRect(_ brick: Brick) -> CGRect {
        let margin: CGFloat = 10
        let gap: CGFloat = 4
        let columns = CGFloat(pattern.columns)
        let rows = CGFloat(pattern.rows.count)
        let width = (playWidth - margin * 2 - gap * (columns - 1)) / columns
        let height = min(26, max(14, size.height * 0.028))
        let top: CGFloat
        switch mode {
        case .solo:
            top = soloTopWall + max(30, size.height * 0.06)
        case .duo:
            top = size.height / 2 - (rows * (height + gap) - gap) / 2
        }
        return CGRect(
            x: playLeft + margin + CGFloat(brick.column) * (width + gap),
            y: top + CGFloat(brick.row) * (height + gap),
            width: width,
            height: height
        )
    }

    /// Called whenever the screen changes, like when the iPhone Duo opens or closes.
    func setLayout(size newSize: CGSize, insets newInsets: EdgeInsets) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        let oldSize = size
        size = newSize
        insets = newInsets
        guard oldSize.width > 0, oldSize != newSize else { return }

        // Stretch everything that moves so it lands in the same spot on the new screen.
        let sx = newSize.width / oldSize.width
        let sy = newSize.height / oldSize.height
        for i in balls.indices {
            balls[i].pos = CGPoint(x: balls[i].pos.x * sx, y: balls[i].pos.y * sy)
        }
        for i in drops.indices {
            drops[i].pos = CGPoint(x: drops[i].pos.x * sx, y: drops[i].pos.y * sy)
        }
        // The screen changed under the players' fingers. Give them a moment.
        if phase == .playing { pause() }
    }

    // MARK: - Game flow

    func start(_ newMode: GameMode) {
        mode = newMode
        level = 1
        lives = [3, 3]
        score = [0, 0]
        winner = nil
        speed = 0.6
        loadLevel()
        phase = .playing
        displayLink.start()
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        lastTimestamp = nil
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        lastTimestamp = nil
    }

    func quitToMenu() {
        phase = .menu
        displayLink.stop()
        balls = []
        drops = []
    }

    private func loadLevel() {
        switch mode {
        case .solo: pattern = Levels.solo(level: level)
        case .duo: pattern = Levels.duo.randomElement() ?? Levels.duo[0]
        }
        bricks = pattern.bricks()
        drops = []
        wideTime = [0, 0]
        slowTime = 0
        paddleX = [0.5, 0.5]
        balls = players.map { stuckBall(on: $0) }
        lastTimestamp = nil
    }

    private func stuckBall(on player: Int) -> Ball {
        Ball(pos: ballSpotOnPaddle(player), dir: CGVector(dx: 0, dy: player == 0 ? -1 : 1),
             owner: player, stuckTo: player, bonus: false)
    }

    private func ballSpotOnPaddle(_ player: Int) -> CGPoint {
        let rect = paddleRect(player)
        let y = player == 0 ? rect.minY - ballRadius - 1 : rect.maxY + ballRadius + 1
        return CGPoint(x: rect.midX, y: y)
    }

    private func launch(_ player: Int) {
        for i in balls.indices where balls[i].stuckTo == player {
            balls[i].stuckTo = nil
            balls[i].dir = normalized(CGVector(dx: CGFloat.random(in: -0.35...0.35), dy: player == 0 ? -1 : 1))
        }
    }

    // MARK: - Touch

    private func player(at point: CGPoint) -> Int {
        mode == .duo && point.y < size.height / 2 ? 1 : 0
    }

    func touchBegan(_ id: ObjectIdentifier, at point: CGPoint) {
        touchOwner[id] = player(at: point)
        touchLastX[id] = point.x
    }

    func touchMoved(_ id: ObjectIdentifier, to point: CGPoint) {
        guard phase == .playing, let player = touchOwner[id], let lastX = touchLastX[id] else { return }
        touchLastX[id] = point.x
        // Drag anywhere on your side. The paddle follows the finger's movement.
        movePaddle(player, by: (point.x - lastX) / playWidth)
    }

    func touchEnded(_ id: ObjectIdentifier) {
        if phase == .playing, let player = touchOwner[id] { launch(player) }
        touchOwner[id] = nil
        touchLastX[id] = nil
    }

    private func movePaddle(_ player: Int, by amount: CGFloat) {
        let half = paddleWidth(player) / 2 / playWidth
        paddleX[player] = min(max(paddleX[player] + amount * 1.2, half), 1 - half)
    }

    // MARK: - Frame loop

    private func frame(_ timestamp: CFTimeInterval) {
        defer { lastTimestamp = timestamp }
        guard phase == .playing, let last = lastTimestamp, size.width > 0 else { return }
        let dt = min(timestamp - last, 1.0 / 30)
        step(dt)
        objectWillChange.send()
    }

    private func step(_ dt: Double) {
        for p in 0..<2 {
            wideTime[p] = max(0, wideTime[p] - dt)
            // A wide paddle may now poke out of the screen. Nudge it back in.
            movePaddle(p, by: 0)
        }
        slowTime = max(0, slowTime - dt)

        let pixelsPerSecond = speed * max(size.width, size.height) * (slowTime > 0 ? 0.65 : 1)
        let r = ballRadius
        var lost: [(ball: Ball, player: Int)] = []
        var kept: [Ball] = []

        for var ball in balls {
            if let player = ball.stuckTo {
                ball.pos = ballSpotOnPaddle(player)
                kept.append(ball)
                continue
            }
            let distance = pixelsPerSecond * CGFloat(dt)
            let steps = max(1, Int((distance / (r * 0.8)).rounded(.up)))
            let stepLength = distance / CGFloat(steps)
            var exit: Int?
            for _ in 0..<steps {
                ball.pos.x += ball.dir.dx * stepLength
                ball.pos.y += ball.dir.dy * stepLength
                bounceOffWalls(&ball)
                bounceOffPaddles(&ball)
                hitBricks(&ball)
                if ball.pos.y - r > size.height { exit = 0; break }
                if mode == .duo, ball.pos.y + r < 0 { exit = 1; break }
            }
            if let exit {
                lost.append((ball, exit))
            } else {
                kept.append(ball)
            }
        }
        balls = kept
        for item in lost { loseBall(item.ball, player: item.player) }

        moveDrops(dt)

        if phase == .playing, !bricks.contains(where: { $0.alive && !$0.steel }) {
            clearLevel()
        }
    }

    private func bounceOffWalls(_ ball: inout Ball) {
        let r = ballRadius
        if ball.pos.x - r < playLeft, ball.dir.dx < 0 {
            ball.pos.x = playLeft + r
            ball.dir.dx = -ball.dir.dx
        } else if ball.pos.x + r > playRight, ball.dir.dx > 0 {
            ball.pos.x = playRight - r
            ball.dir.dx = -ball.dir.dx
        }
        if mode == .solo, ball.pos.y - r < soloTopWall, ball.dir.dy < 0 {
            ball.pos.y = soloTopWall + r
            ball.dir.dy = -ball.dir.dy
        }
    }

    private func bounceOffPaddles(_ ball: inout Ball) {
        let r = ballRadius
        for player in players {
            let rect = paddleRect(player)
            let movingToward = player == 0 ? ball.dir.dy > 0 : ball.dir.dy < 0
            guard movingToward, circle(ball.pos, r, touches: rect) else { continue }
            // Still in front of the paddle, not already past it.
            if player == 0, ball.pos.y > rect.maxY { continue }
            if player == 1, ball.pos.y < rect.minY { continue }

            // Where it hits decides the angle: the edges send it out sideways.
            let offset = min(max((ball.pos.x - rect.midX) / (rect.width / 2), -1), 1)
            let angle = offset * .pi / 3
            ball.dir = CGVector(dx: sin(angle), dy: player == 0 ? -cos(angle) : cos(angle))
            ball.pos.y = player == 0 ? rect.minY - r : rect.maxY + r
            ball.owner = player
            speed = min(speed + 0.006, 1.15)
            Haptics.tap()
        }
    }

    private func hitBricks(_ ball: inout Ball) {
        let r = ballRadius
        for i in bricks.indices where bricks[i].alive {
            let rect = brickRect(bricks[i])
            let closest = CGPoint(x: min(max(ball.pos.x, rect.minX), rect.maxX),
                                  y: min(max(ball.pos.y, rect.minY), rect.maxY))
            let dx = ball.pos.x - closest.x
            let dy = ball.pos.y - closest.y
            guard dx * dx + dy * dy < r * r else { continue }

            // Bounce off the side it hit.
            if abs(dx) > abs(dy) {
                if dx * ball.dir.dx < 0 { ball.dir.dx = -ball.dir.dx }
                ball.pos.x = dx > 0 ? rect.maxX + r : rect.minX - r
            } else {
                if dy * ball.dir.dy < 0 || dy == 0 { ball.dir.dy = -ball.dir.dy }
                ball.pos.y = dy > 0 ? rect.maxY + r : rect.minY - r
            }
            keepAngleSane(&ball)

            if bricks[i].steel {
                Haptics.tap()
                return
            }
            bricks[i].hp -= 1
            score[ball.owner] += 10
            if bricks[i].hp <= 0 {
                score[ball.owner] += 15
                Haptics.pop()
                if Double.random(in: 0..<1) < 0.14 {
                    drops.append(Drop(pos: CGPoint(x: rect.midX, y: rect.midY), kind: .random(), toward: ball.owner))
                }
            } else {
                Haptics.tap()
            }
            return
        }
    }

    /// Stops the ball from sliding almost sideways forever.
    private func keepAngleSane(_ ball: inout Ball) {
        if abs(ball.dir.dy) < 0.3 {
            ball.dir.dy = ball.dir.dy < 0 ? -0.3 : 0.3
        }
        ball.dir = normalized(ball.dir)
    }

    private func loseBall(_ ball: Ball, player: Int) {
        if ball.bonus { return }
        if let i = balls.firstIndex(where: { $0.bonus && $0.owner == player || ($0.bonus && mode == .solo) }) {
            balls[i].bonus = false
            return
        }
        lives[player] -= 1
        Haptics.ouch()
        if lives[player] > 0 {
            balls.append(stuckBall(on: player))
            return
        }
        switch mode {
        case .solo:
            saveBest()
        case .duo:
            winner = 1 - player
        }
        phase = .over
    }

    private func clearLevel() {
        switch mode {
        case .solo:
            level += 1
            speed = min(0.6 + CGFloat(level - 1) * 0.05, 0.95)
            phase = .levelCleared
            Haptics.win()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard phase == .levelCleared else { return }
                loadLevel()
                phase = .playing
            }
        case .duo:
            winner = score[0] == score[1] ? nil : (score[0] > score[1] ? 0 : 1)
            phase = .over
            Haptics.win()
        }
    }

    private func saveBest() {
        if score[0] > best {
            best = score[0]
            UserDefaults.standard.set(best, forKey: "best")
        }
    }

    // MARK: - Power-ups

    func dropRect(_ drop: Drop) -> CGRect {
        CGRect(x: drop.pos.x - 16, y: drop.pos.y - 10, width: 32, height: 20)
    }

    private func moveDrops(_ dt: Double) {
        let fall = max(size.width, size.height) * 0.22 * CGFloat(dt)
        var kept: [Drop] = []
        for var drop in drops {
            drop.pos.y += drop.toward == 0 ? fall : -fall
            if dropRect(drop).intersects(paddleRect(drop.toward)) {
                apply(drop.kind, to: drop.toward)
            } else if drop.pos.y > -30, drop.pos.y < size.height + 30 {
                kept.append(drop)
            }
        }
        drops = kept
    }

    private func apply(_ kind: PowerKind, to player: Int) {
        Haptics.pop()
        switch kind {
        case .wide:
            wideTime[player] = 10
        case .multi:
            guard let source = balls.first(where: { $0.stuckTo == nil && $0.owner == player })
                ?? balls.first(where: { $0.stuckTo == nil }) else { return }
            for turn in [-0.45, 0.45] {
                var extra = source
                extra.bonus = true
                extra.owner = player
                extra.dir = rotated(source.dir, by: turn)
                keepAngleSane(&extra)
                balls.append(extra)
            }
        case .slow:
            slowTime = 8
        case .life:
            lives[player] = min(lives[player] + 1, 5)
        }
    }

    // MARK: - Math

    private func circle(_ center: CGPoint, _ r: CGFloat, touches rect: CGRect) -> Bool {
        let x = min(max(center.x, rect.minX), rect.maxX)
        let y = min(max(center.y, rect.minY), rect.maxY)
        let dx = center.x - x
        let dy = center.y - y
        return dx * dx + dy * dy < r * r
    }

    private func normalized(_ v: CGVector) -> CGVector {
        let length = max(sqrt(v.dx * v.dx + v.dy * v.dy), 0.0001)
        return CGVector(dx: v.dx / length, dy: v.dy / length)
    }

    private func rotated(_ v: CGVector, by angle: Double) -> CGVector {
        let c = CGFloat(cos(angle))
        let s = CGFloat(sin(angle))
        return CGVector(dx: v.dx * c - v.dy * s, dy: v.dx * s + v.dy * c)
    }
}

/// Calls back once per screen refresh (up to 120 times a second).
final class DisplayLink: NSObject {
    private var link: CADisplayLink?
    private let onFrame: @MainActor (CFTimeInterval) -> Void

    init(onFrame: @escaping @MainActor (CFTimeInterval) -> Void) {
        self.onFrame = onFrame
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let timestamp = link.timestamp
        MainActor.assumeIsolated { onFrame(timestamp) }
    }
}
