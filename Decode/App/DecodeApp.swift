import SwiftUI

@main
struct DecodeApp: App {
    @State private var studio = Studio()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(studio)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}
