import SwiftUI

@main
struct DuoBreakoutApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            GameView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
