import SwiftUI

/// The start screen. When the iPhone Duo is open, two player mode is the star.
struct MenuView: View {
    let posture: Posture
    let best: Int
    let start: (GameMode) -> Void

    var body: some View {
        VStack(spacing: 22) {
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
                NeonButton(title: "2 PLAYERS", color: Theme.players[1]) { start(.duo) }
                NeonButton(title: "1 PLAYER", small: true) { start(.solo) }
                Text("Lay the phone flat between you. Each player drags on their own half.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: 320)
            } else {
                NeonButton(title: "PLAY") { start(.solo) }
                NeonButton(title: "2 PLAYERS", color: Theme.players[1], small: true) { start(.duo) }
                Text("Open your iPhone Duo for the best 2 player game.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: 300)
            }

            if best > 0 {
                Text("BEST \(best)")
                    .font(Theme.title(16))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
    }
}
