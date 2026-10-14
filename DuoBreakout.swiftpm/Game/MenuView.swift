import SwiftUI

/// The start screen. When the iPhone Duo is open, two player mode is the star.
struct MenuView: View {
    let posture: Posture
    let best: Int
    let openShop: () -> Void
    let start: (GameMode, PartyRule) -> Void

    @EnvironmentObject private var store: Store
    @State private var rule: PartyRule = .classic

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 20) {
                title

                HStack(spacing: 8) {
                    Image(systemName: posture == .open ? "book.pages" : "iphone")
                    Text(posture == .open ? "Open - 2 players ready" : "Closed or tent mode")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())

                if posture == .open {
                    partyPicker
                    NeonButton(title: "2 PLAYERS", color: Theme.players[1]) { startDuo() }
                    NeonButton(title: "1 PLAYER", small: true) { start(.solo, .classic) }
                    hint("Lay the phone flat between you. Each player drags on their own half.")
                } else {
                    NeonButton(title: "PLAY") { start(.solo, .classic) }
                    NeonButton(title: "2 PLAYERS", color: Theme.players[1], small: true) { startDuo() }
                    hint("Open your iPhone Duo for the best 2 player game.")
                }

                Button(action: openShop) {
                    Label("SHOP", systemImage: "bag.fill")
                        .font(Theme.title(16))
                        .foregroundStyle(Skin.gold.bricks[0])
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Skin.gold.bricks[0].opacity(0.7), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                if best > 0 {
                    Text("BEST \(best)")
                        .font(Theme.title(16))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(24)
            // Centered when it fits, scrollable when the screen is short (tent mode).
            .frame(maxWidth: .infinity, minHeight: geo.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var title: some View {
        VStack(spacing: 0) {
            Text("DUO")
                .font(Theme.title(30))
                .foregroundStyle(Theme.players[1])
                .shadow(color: Theme.players[1], radius: 10)
            Text("BREAKOUT")
                .font(Theme.title(52))
                .foregroundStyle(Theme.players[0])
                .shadow(color: Theme.players[0], radius: 14)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    /// Classic is free. The other modes open the shop until Party Modes is bought.
    private var partyPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(PartyRule.allCases) { option in
                    let locked = !option.isFree && !store.owns(StoreIDs.party)
                    Button {
                        if locked { openShop() } else { rule = option }
                    } label: {
                        HStack(spacing: 4) {
                            if locked { Image(systemName: "lock.fill").font(.system(size: 10)) }
                            Text(option.name)
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(rule == option ? Color.black : Color.white.opacity(locked ? 0.5 : 0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(rule == option ? Theme.players[1] : Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(rule.detail)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func startDuo() {
        let allowed = rule.isFree || store.owns(StoreIDs.party)
        start(.duo, allowed ? rule : .classic)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: 320)
    }
}
