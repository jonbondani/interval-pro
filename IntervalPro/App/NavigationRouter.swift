import SwiftUI

/// Centralized navigation management for the app
@MainActor
final class NavigationRouter: ObservableObject {
    // MARK: - Navigation Paths
    @Published var homePath = NavigationPath()
    @Published var progressPath = NavigationPath()
    @Published var profilePath = NavigationPath()

    // MARK: - Sheet Presentation
    @Published var presentedSheet: Sheet?
    @Published var presentedFullScreenCover: FullScreenCover?

    // MARK: - Alert
    @Published var alertItem: AlertItem?

    // MARK: - Navigation Destinations
    enum Destination: Hashable {
        case planBuilder
        case planDetail(planId: UUID)
        case training(planId: UUID)
        case sessionDetail(sessionId: UUID)
        case sessionHistory
        case settings
        case garminPairing
    }

    // MARK: - Sheets
    enum Sheet: Identifiable {
        case planTemplates
        case metronomeSettings
        case shareSession(sessionId: UUID)

        var id: String {
            switch self {
            case .planTemplates: return "planTemplates"
            case .metronomeSettings: return "metronomeSettings"
            case .shareSession(let id): return "shareSession-\(id)"
            }
        }
    }

    // MARK: - Full Screen Covers
    enum FullScreenCover: Identifiable {
        case activeTraining(planId: UUID)
        case sessionSummary(sessionId: UUID)

        var id: String {
            switch self {
            case .activeTraining(let id): return "training-\(id)"
            case .sessionSummary(let id): return "summary-\(id)"
            }
        }
    }

    // MARK: - Alert
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryButton: Alert.Button
        let secondaryButton: Alert.Button?

        init(
            title: String,
            message: String,
            primaryButton: Alert.Button = .default(Text("OK")),
            secondaryButton: Alert.Button? = nil
        ) {
            self.title = title
            self.message = message
            self.primaryButton = primaryButton
            self.secondaryButton = secondaryButton
        }
    }

    // MARK: - Navigation Methods
    func navigate(to destination: Destination) {
        homePath.append(destination)
    }

    func presentSheet(_ sheet: Sheet) {
        presentedSheet = sheet
    }

    func presentFullScreen(_ cover: FullScreenCover) {
        presentedFullScreenCover = cover
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func dismissFullScreen() {
        presentedFullScreenCover = nil
    }

    func showAlert(_ item: AlertItem) {
        alertItem = item
    }

    func popToRoot() {
        homePath = NavigationPath()
    }

    func pop() {
        guard !homePath.isEmpty else { return }
        homePath.removeLast()
    }
}
