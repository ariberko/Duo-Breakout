import UIKit

/// Little buzzes so you can feel the game.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    static func tap() { light.impactOccurred(intensity: 0.6) }
    static func pop() { rigid.impactOccurred() }
    static func ouch() { notify.notificationOccurred(.error) }
    static func win() { notify.notificationOccurred(.success) }
}
