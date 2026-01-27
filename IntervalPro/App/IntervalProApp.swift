import SwiftUI

@main
struct IntervalProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var navigationRouter = NavigationRouter()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(navigationRouter)
        }
    }

    private func configureAppearance() {
        // Configure global appearance settings
        // Using semantic colors that adapt to dark/light mode
    }
}
