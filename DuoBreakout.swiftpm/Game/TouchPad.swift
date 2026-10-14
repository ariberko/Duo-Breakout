import SwiftUI
import UIKit

/// A see-through layer that reports every finger, so two players can drag at the same time.
struct TouchPad: UIViewRepresentable {
    let engine: GameEngine

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.engine = engine
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.engine = engine
    }

    final class TouchView: UIView {
        weak var engine: GameEngine?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                engine?.touchBegan(ObjectIdentifier(touch), at: touch.location(in: self))
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                engine?.touchMoved(ObjectIdentifier(touch), to: touch.location(in: self))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { engine?.touchEnded(ObjectIdentifier(touch)) }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches { engine?.touchEnded(ObjectIdentifier(touch)) }
        }
    }
}
