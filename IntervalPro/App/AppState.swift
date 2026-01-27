import SwiftUI
import Combine

/// Global application state container
@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State
    @Published var isOnboardingComplete: Bool
    @Published var hasHealthKitPermission: Bool = false
    @Published var hasGarminConnected: Bool = false
    @Published var currentUser: UserProfile?

    // MARK: - Dependencies
    private let userDefaults: UserDefaults

    // MARK: - Constants
    private enum Keys {
        static let onboardingComplete = "onboarding_complete"
    }

    // MARK: - Init
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isOnboardingComplete = userDefaults.bool(forKey: Keys.onboardingComplete)
    }

    // MARK: - Methods
    func completeOnboarding() {
        isOnboardingComplete = true
        userDefaults.set(true, forKey: Keys.onboardingComplete)
    }

    func resetOnboarding() {
        isOnboardingComplete = false
        userDefaults.set(false, forKey: Keys.onboardingComplete)
    }
}

// MARK: - User Profile
struct UserProfile: Codable, Equatable {
    let id: UUID
    var name: String
    var preferredLanguage: String
    var maxHeartRate: Int?
    var restingHeartRate: Int?

    init(
        id: UUID = UUID(),
        name: String = "",
        preferredLanguage: String = Locale.current.language.languageCode?.identifier ?? "es",
        maxHeartRate: Int? = nil,
        restingHeartRate: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.preferredLanguage = preferredLanguage
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
    }
}
