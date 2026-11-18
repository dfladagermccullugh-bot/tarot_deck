import SwiftUI

@main
struct TarotApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .preferredColorScheme(.dark)
        }
    }
}
