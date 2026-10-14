import SwiftUI

@main
struct DuoBreakoutApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
        }
    }
}
