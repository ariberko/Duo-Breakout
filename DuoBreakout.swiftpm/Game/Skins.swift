import SwiftUI

/// A look for the whole game: background, bricks, paddles and ball.
struct Skin: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    /// nil means free.
    let productID: String?
    let background: [Color]
    let bricks: [Color]
    /// Paddle colors for player 1 (bottom) and player 2 (top).
    let players: [Color]
    let ball: Color
    var squareBall = false
    var brickCorner: CGFloat = 4
    var glow: Double = 0.6
    var stars = false

    static func == (a: Skin, b: Skin) -> Bool { a.id == b.id }

    static let neon = Skin(
        id: "neon", name: "Neon", tagline: "The classic glow.", productID: nil,
        background: [Color(red: 0.04, green: 0.03, blue: 0.12), Color(red: 0.10, green: 0.02, blue: 0.18)],
        bricks: Theme.rows, players: Theme.players, ball: .white
    )

    static let retro = Skin(
        id: "retro", name: "Retro", tagline: "Old arcade screen. Square ball.", productID: StoreIDs.skinRetro,
        background: [Color(red: 0.0, green: 0.05, blue: 0.0), Color(red: 0.0, green: 0.09, blue: 0.02)],
        bricks: [Color(red: 0.2, green: 1.0, blue: 0.3), Color(red: 0.1, green: 0.8, blue: 0.2), Color(red: 0.5, green: 1.0, blue: 0.5)],
        players: [Color(red: 0.3, green: 1.0, blue: 0.4), Color(red: 1.0, green: 0.75, blue: 0.1)],
        ball: Color(red: 0.7, green: 1.0, blue: 0.7), squareBall: true, brickCorner: 0, glow: 0.9
    )

    static let candy = Skin(
        id: "candy", name: "Candy", tagline: "Sweet pastel bricks.", productID: StoreIDs.skinCandy,
        background: [Color(red: 0.25, green: 0.12, blue: 0.25), Color(red: 0.35, green: 0.15, blue: 0.3)],
        bricks: [Color(red: 1.0, green: 0.7, blue: 0.8), Color(red: 0.75, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.95, blue: 0.7),
                 Color(red: 0.8, green: 1.0, blue: 0.8), Color(red: 0.9, green: 0.8, blue: 1.0)],
        players: [Color(red: 1.0, green: 0.55, blue: 0.75), Color(red: 0.55, green: 0.8, blue: 1.0)],
        ball: Color(red: 1.0, green: 0.95, blue: 0.98), brickCorner: 9, glow: 0.4
    )

    static let space = Skin(
        id: "space", name: "Space", tagline: "Break bricks among the stars.", productID: StoreIDs.skinSpace,
        background: [Color(red: 0.0, green: 0.0, blue: 0.05), Color(red: 0.03, green: 0.02, blue: 0.12)],
        bricks: [Color(red: 0.55, green: 0.4, blue: 1.0), Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.3, green: 0.8, blue: 1.0),
                 Color(red: 0.85, green: 0.5, blue: 1.0)],
        players: [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.9, green: 0.5, blue: 1.0)],
        ball: Color(red: 1.0, green: 0.95, blue: 0.75), brickCorner: 3, glow: 0.8, stars: true
    )

    static let lava = Skin(
        id: "lava", name: "Lava", tagline: "Hot bricks. Don't touch.", productID: StoreIDs.skinLava,
        background: [Color(red: 0.12, green: 0.01, blue: 0.0), Color(red: 0.25, green: 0.03, blue: 0.0)],
        bricks: [Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 1.0, green: 0.3, blue: 0.1),
                 Color(red: 0.85, green: 0.1, blue: 0.1)],
        players: [Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 1.0, green: 0.25, blue: 0.2)],
        ball: Color(red: 1.0, green: 1.0, blue: 0.8), brickCorner: 6, glow: 1.0
    )

    static let gold = Skin(
        id: "gold", name: "Gold", tagline: "Shiny. Fancy. Show off.", productID: StoreIDs.skinGold,
        background: [Color(red: 0.05, green: 0.04, blue: 0.02), Color(red: 0.1, green: 0.08, blue: 0.03)],
        bricks: [Color(red: 1.0, green: 0.84, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.2), Color(red: 1.0, green: 0.92, blue: 0.6)],
        players: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 0.85, green: 0.85, blue: 0.9)],
        ball: .white, brickCorner: 5, glow: 0.9
    )

    static let all: [Skin] = [.neon, .retro, .candy, .space, .lava, .gold]

    static func with(id: String) -> Skin {
        all.first { $0.id == id } ?? .neon
    }
}

/// Fixed star positions (0...1) for the Space skin.
enum StarField {
    static let stars: [(x: CGFloat, y: CGFloat, size: CGFloat)] = {
        var seed: UInt64 = 42
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 10_000) / 10_000
        }
        return (0..<90).map { _ in (next(), next(), 0.6 + next() * 1.6) }
    }()
}
