import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.04, green: 0.03, blue: 0.12), Color(red: 0.10, green: 0.02, blue: 0.18)],
        startPoint: .top, endPoint: .bottom
    )
    /// Player 1 (bottom) and player 2 (top).
    static let players = [Color(red: 0.2, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.3, blue: 0.75)]
    static let rows: [Color] = [
        Color(red: 1.00, green: 0.30, blue: 0.45),
        Color(red: 1.00, green: 0.55, blue: 0.20),
        Color(red: 1.00, green: 0.85, blue: 0.25),
        Color(red: 0.35, green: 0.95, blue: 0.45),
        Color(red: 0.25, green: 0.80, blue: 1.00),
        Color(red: 0.55, green: 0.45, blue: 1.00),
        Color(red: 0.95, green: 0.40, blue: 1.00),
    ]
    static let steel = Color(white: 0.55)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

/// A big glowing button.
struct NeonButton: View {
    let title: String
    var color: Color = Theme.players[0]
    var small = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.title(small ? 17 : 22))
                .foregroundStyle(.black)
                .frame(minWidth: small ? 140 : 220)
                .padding(.vertical, small ? 10 : 14)
                .background(color, in: Capsule())
                .shadow(color: color.opacity(0.8), radius: 12)
        }
        .buttonStyle(.plain)
    }
}
