import CoreGraphics

/// How the iPhone Duo is being held, guessed from the screen's shape.
/// Apple asks apps to use the screen size instead of asking "is it folded?",
/// so a big, almost square screen means "open" and anything else means "closed or tent".
enum Posture {
    case closed
    case open

    init(size: CGSize) {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        self = short >= 560 && short / max(long, 1) > 0.68 ? .open : .closed
    }
}
