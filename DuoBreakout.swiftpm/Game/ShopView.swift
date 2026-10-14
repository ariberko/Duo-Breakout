import StoreKit
import SwiftUI

/// The shop: skins, the Level Pack, Party Modes, All Access and a tip jar.
struct ShopView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("skin") private var skinID = Skin.neon.id
    @State private var buying: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if !store.hasEverything {
                        allAccessCard
                    }

                    section("SKINS") {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Skin.all) { skin in skinCard(skin) }
                        }
                    }

                    section("MORE GAME") {
                        unlockRow(id: StoreIDs.levels, title: "Level Pack",
                                  detail: "12 new one player levels. 18 in total.", symbol: "square.grid.3x3.fill")
                        unlockRow(id: StoreIDs.party, title: "Party Modes",
                                  detail: "Multiball, Rush and Chaos for 2 players.", symbol: "person.2.fill")
                    }

                    section("TIP JAR") {
                        Text("Made by one person. Tips keep new skins and levels coming.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        HStack(spacing: 12) {
                            tipButton(StoreIDs.tipSmall, emoji: "☕️")
                            tipButton(StoreIDs.tipBig, emoji: "🍕")
                        }
                    }

                    Button {
                        Task { await store.restore() }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            if store.isRestoring { ProgressView().tint(.white) }
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(store.isRestoring)

                    if store.products.isEmpty && !store.isLoading {
                        Text("Prices couldn't load. Check your internet and open the shop again.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            await store.refreshEntitlements()
        }
        .alert("Shop", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.message ?? "")
        }
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.title(15))
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
    }

    private var allAccessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill").font(.system(size: 30))
                Text("ALL ACCESS").font(Theme.title(26))
            }
            .foregroundStyle(Skin.gold.bricks[0])
            Text("Every skin, the Level Pack and Party Modes. Plus everything added later.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            priceButton(StoreIDs.allAccess, color: Skin.gold.bricks[0])
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Skin.gold.bricks[0].opacity(0.6), lineWidth: 1.5))
        )
    }

    private func skinCard(_ skin: Skin) -> some View {
        let owned = store.owns(skin)
        let inUse = skinID == skin.id
        return VStack(alignment: .leading, spacing: 8) {
            SkinPreview(skin: skin)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(inUse ? skin.players[0] : .clear, lineWidth: 3))
            Text(skin.name).font(Theme.title(17)).foregroundStyle(.white)
            Text(skin.tagline)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2, reservesSpace: true)
            if owned {
                Button {
                    skinID = skin.id
                } label: {
                    Text(inUse ? "IN USE" : "USE")
                        .font(Theme.title(14))
                        .foregroundStyle(inUse ? Color.white.opacity(0.6) : Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(inUse ? Color.white.opacity(0.1) : skin.players[0], in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(inUse)
            } else if let id = skin.productID {
                priceButton(id, color: skin.players[0])
            }
        }
    }

    private func unlockRow(id: String, title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Theme.players[0])
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(17)).foregroundStyle(.white)
                Text(detail).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if store.owns(id) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Skin.retro.players[0])
            } else {
                priceButton(id, color: Theme.players[0]).frame(width: 90)
            }
        }
    }

    private func tipButton(_ id: String, emoji: String) -> some View {
        Button {
            buy(id)
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 30))
                Text(store.product(id)?.displayPrice ?? "...")
                    .font(Theme.title(15))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(store.product(id) == nil || buying != nil)
    }

    private func priceButton(_ id: String, color: Color) -> some View {
        Button {
            buy(id)
        } label: {
            Group {
                if buying == id {
                    ProgressView().tint(.black)
                } else {
                    Text(store.product(id)?.displayPrice ?? "...")
                }
            }
            .font(Theme.title(15))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.product(id) == nil || buying != nil)
    }

    private func buy(_ id: String) {
        guard let product = store.product(id) else { return }
        buying = id
        Task {
            await store.buy(product)
            buying = nil
            // Wear a new skin right after buying it.
            if let skin = Skin.all.first(where: { $0.productID == id }), store.owns(skin) {
                skinID = skin.id
            }
        }
    }
}

/// A tiny picture of a skin: bricks, a paddle and a ball.
struct SkinPreview: View {
    let skin: Skin

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: skin.background), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            if skin.stars {
                for star in StarField.stars.prefix(30) {
                    context.fill(Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height,
                                                        width: star.size, height: star.size)),
                                 with: .color(.white.opacity(0.7)))
                }
            }
            let columns = 6
            let gap: CGFloat = 3
            let width = (size.width - 16 - gap * CGFloat(columns - 1)) / CGFloat(columns)
            for row in 0..<3 {
                for column in 0..<columns {
                    let rect = CGRect(x: 8 + CGFloat(column) * (width + gap), y: 12 + CGFloat(row) * 13,
                                      width: width, height: 10)
                    context.fill(Path(roundedRect: rect, cornerRadius: min(skin.brickCorner, 4)),
                                 with: .color(skin.bricks[row % skin.bricks.count]))
                }
            }
            context.drawLayer { glow in
                glow.addFilter(.shadow(color: skin.players[0].opacity(skin.glow), radius: 6))
                let paddle = CGRect(x: size.width / 2 - 26, y: size.height - 18, width: 52, height: 7)
                glow.fill(Path(roundedRect: paddle, cornerRadius: 3.5), with: .color(skin.players[0]))
                let ball = CGRect(x: size.width / 2 + 14, y: size.height - 42, width: 9, height: 9)
                glow.fill(skin.squareBall ? Path(ball) : Path(ellipseIn: ball), with: .color(skin.ball))
            }
        }
    }
}
