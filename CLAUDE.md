# CLAUDE.md - IntervalPro iOS

## Project Overview

**IntervalPro** is an iOS interval training app for runners focused on heart rate zone-based HIIT workouts with Garmin Fenix integration and audio metronome overlay on streaming music.

**Target Release:** Q1 2026
**Min iOS:** 16.0
**PRD:** See `PRD_IntervalPro.md`

---

## Tech Stack

### Core Frameworks

| Framework | Purpose | Notes |
|-----------|---------|-------|
| **SwiftUI** | UI layer | iOS 16+, no UIKit |
| **HealthKit** | HR data, workout write | Primary HR source fallback |
| **CoreBluetooth** | Garmin Fenix connection | BLE HR Service 0x180D |
| **AVFoundation** | Metronome audio engine | AVAudioSession mixing |
| **CoreData** | Local persistence | Encrypted, historical sessions |
| **Swift Charts** | Visualizations | Progress trends, HR graphs |

### External SDKs

| SDK | Purpose | Integration |
|-----|---------|-------------|
| **Garmin Connect IQ SDK** | Watch communication | BT pairing, AutoLap commands |
| **Spotify iOS SDK** | Music control overlay | Optional, Premium users |
| **MusicKit** | Apple Music API | Native integration |
| **Firebase** | Analytics, Crashlytics | Privacy-compliant config |

### Architecture

```
IntervalPro/
├── App/
│   └── IntervalProApp.swift
├── Features/
│   ├── Training/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Plans/
│   ├── Progress/
│   └── Settings/
├── Core/
│   ├── Bluetooth/
│   │   └── GarminManager.swift
│   ├── Health/
│   │   └── HealthKitManager.swift
│   ├── Audio/
│   │   └── MetronomeEngine.swift
│   └── Persistence/
│       └── CoreDataStack.swift
├── Shared/
│   ├── Extensions/
│   ├── Components/
│   └── Utilities/
└── Tests/
    ├── UnitTests/
    └── UITests/
```

---

## Immutable Rules

### 1. TDD with XCTest

```swift
// ALWAYS write tests FIRST
// Minimum 80% code coverage for business logic

// Example: Test interval timer logic BEFORE implementation
func test_intervalTimer_transitionsToRestPhase_afterWorkDuration() async {
    let sut = IntervalTimer(workDuration: 180, restDuration: 180)

    await sut.start()
    await sut.advanceTime(by: 180)

    XCTAssertEqual(sut.currentPhase, .rest)
}

// Required test categories:
// - Unit tests: ViewModels, Managers, business logic
// - Integration tests: HealthKit, CoreBluetooth flows
// - UI tests: Critical user journeys (start workout, complete session)
```

### 2. Privacy Compliance (HR Data)

```swift
// CRITICAL: Heart rate is sensitive health data

// Encryption requirements:
// - CoreData: NSPersistentStoreDescription with encryption
// - Keychain: All tokens and API keys
// - No raw HR samples in cloud sync

// Required permissions justification in Info.plist:
// - NSHealthShareUsageDescription
// - NSHealthUpdateUsageDescription
// - NSBluetoothAlwaysUsageDescription
// - NSBluetoothPeripheralUsageDescription

// Data handling:
class HealthDataManager {
    // NEVER log HR values in production
    func logHRSample(_ sample: HRSample) {
        #if DEBUG
        print("HR: \(sample.bpm)")
        #endif
        // Production: only log anonymized aggregates
    }

    // ALWAYS provide data deletion
    func deleteAllUserData() async throws {
        try await coreDataStack.deleteAllSessions()
        try await healthKitManager.revokeAuthorization()
        KeychainManager.clearAll()
    }
}
```

### 3. Responsive UI (iPhone + Watch)

```swift
// All views MUST support:
// - Dynamic Type (accessibility)
// - Dark/Light mode
// - Multiple screen sizes
// - Landscape orientation for training screen

struct TrainingView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        // Use GeometryReader for critical layouts
        GeometryReader { geo in
            if sizeClass == .compact {
                CompactTrainingLayout(size: geo.size)
            } else {
                RegularTrainingLayout(size: geo.size)
            }
        }
        .font(.system(.title, design: .rounded, weight: .bold))
        // ALWAYS use semantic fonts, never fixed sizes
    }
}

// Watch Extension: Separate target, shared ViewModels
// Use WatchConnectivity for session sync
```

### 4. Error Handling (Garmin Disconnect)

```swift
// Garmin connection is UNRELIABLE - always handle gracefully

enum GarminConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(GarminError)
}

class GarminManager: ObservableObject {
    @Published var connectionState: GarminConnectionState = .disconnected

    private let maxReconnectAttempts = 3
    private let reconnectDelay: TimeInterval = 2.0

    // REQUIRED: Automatic reconnection with exponential backoff
    func handleDisconnect() async {
        for attempt in 1...maxReconnectAttempts {
            connectionState = .reconnecting(attempt: attempt)

            try? await Task.sleep(for: .seconds(reconnectDelay * Double(attempt)))

            if await attemptReconnect() {
                connectionState = .connected
                return
            }
        }

        // Fallback to HealthKit
        connectionState = .failed(.maxReconnectAttemptsExceeded)
        await activateHealthKitFallback()

        // Notify user NON-intrusively
        NotificationCenter.default.post(name: .garminFallbackActivated, object: nil)
    }

    // NEVER crash or freeze UI on disconnect
    // ALWAYS have HealthKit fallback ready
}
```

---

## Persona Context

### Primary User Profile

```yaml
Name: Daniel
Age: 52
Location: Marbella, Spain
Occupation: macOS/iOS Developer

Fitness Profile:
  - Training: Calisthenics + HIIT (4-5x/week)
  - Experience: Advanced runner, 5+ years
  - Goals: Improve half-marathon time, optimize zone training

Tech Profile:
  - Primary device: iPhone 15 Pro
  - Watch: Garmin Fenix 7
  - Music: Spotify Premium
  - Expects: Developer-quality UX, no bugs

Behaviors:
  - Runs early morning (6-7 AM)
  - Uses Spanish language
  - Shares workouts on Strava
  - Analyzes metrics post-workout

Pain Points:
  - Hates switching between music and training apps
  - Frustrated by imprecise HR zone alerts
  - Wants clear progress visualization

Success Criteria:
  - "Just works" with Garmin
  - Metronome doesn't interrupt music
  - Can see improvement week over week
```

### Design Implications

```swift
// Localization: Spanish primary, English secondary
Bundle.main.preferredLocalizations = ["es", "en"]

// Font sizes: Larger defaults for outdoor visibility
struct DesignTokens {
    static let hrDisplayFont: Font = .system(size: 72, weight: .bold, design: .rounded)
    static let paceFont: Font = .system(size: 36, weight: .semibold, design: .monospaced)
    static let minimumTapTarget: CGFloat = 44 // Accessibility minimum
}

// Morning runs: Auto dark mode based on ambient light
// or time-based override for early AM
```

---

## Code Style

### Clean Swift Architecture

```swift
// MVVM with Dependency Injection
// ViewModels are @MainActor, use async/await

@MainActor
final class TrainingViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentPhase: IntervalPhase = .idle
    @Published private(set) var heartRate: Int = 0
    @Published private(set) var elapsedTime: TimeInterval = 0

    // MARK: - Dependencies (injected)
    private let garminManager: GarminManaging
    private let healthKitManager: HealthKitManaging
    private let audioEngine: AudioEngineProtocol

    // MARK: - Init
    init(
        garminManager: GarminManaging = GarminManager.shared,
        healthKitManager: HealthKitManaging = HealthKitManager.shared,
        audioEngine: AudioEngineProtocol = MetronomeEngine()
    ) {
        self.garminManager = garminManager
        self.healthKitManager = healthKitManager
        self.audioEngine = audioEngine
    }

    // MARK: - Public Methods
    func startWorkout() async throws {
        // Implementation
    }
}

// Protocols for testability
protocol GarminManaging: AnyObject {
    var heartRatePublisher: AnyPublisher<Int, Never> { get }
    func connect() async throws
    func sendLapMarker() async
}
```

### Async/Await Patterns

```swift
// ALWAYS use structured concurrency
// NEVER use completion handlers for new code

// Correct:
func fetchHeartRateSamples() async throws -> [HRSample] {
    try await healthKitManager.querySamples(
        from: Date().addingTimeInterval(-3600),
        to: Date()
    )
}

// Task groups for parallel operations:
func loadDashboardData() async throws -> DashboardData {
    async let sessions = sessionRepository.fetchRecent(limit: 10)
    async let bestSession = sessionRepository.fetchBest()
    async let weeklyStats = analyticsService.calculateWeeklyStats()

    return try await DashboardData(
        recentSessions: sessions,
        bestSession: bestSession,
        weeklyStats: weeklyStats
    )
}

// Cancellation handling:
func monitorHeartRate() async {
    for await sample in garminManager.heartRateStream {
        guard !Task.isCancelled else { break }
        await MainActor.run {
            self.heartRate = sample.bpm
        }
    }
}
```

### SwiftUI Previews

```swift
// EVERY view MUST have previews
// Multiple configurations: light/dark, sizes, states

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Active workout state
            TrainingView(viewModel: .preview(phase: .work, hr: 168))
                .previewDisplayName("Work Phase")

            // Rest phase
            TrainingView(viewModel: .preview(phase: .rest, hr: 145))
                .previewDisplayName("Rest Phase")
                .preferredColorScheme(.dark)

            // Disconnected state
            TrainingView(viewModel: .preview(garminState: .disconnected))
                .previewDisplayName("Garmin Disconnected")

            // Dynamic type
            TrainingView(viewModel: .preview())
                .environment(\.dynamicTypeSize, .accessibility3)
                .previewDisplayName("Large Dynamic Type")
        }
    }
}

// Preview helpers in dedicated extension:
extension TrainingViewModel {
    static func preview(
        phase: IntervalPhase = .idle,
        hr: Int = 0,
        garminState: GarminConnectionState = .connected
    ) -> TrainingViewModel {
        let vm = TrainingViewModel(
            garminManager: MockGarminManager(state: garminState),
            healthKitManager: MockHealthKitManager(),
            audioEngine: MockAudioEngine()
        )
        vm.currentPhase = phase
        vm.heartRate = hr
        return vm
    }
}
```

---

## Never Do

### 1. UIKit Legacy

```swift
// FORBIDDEN - No UIKit in new code

// BAD:
import UIKit
class TrainingViewController: UIViewController { } // NO
struct TrainingView: UIViewRepresentable { } // NO (unless wrapping 3rd party)

// GOOD:
import SwiftUI
struct TrainingView: View { }

// Exception: Only if wrapping unavoidable UIKit-only API
// Document reason and create abstraction layer
```

### 2. Hardcoded BPM Values

```swift
// FORBIDDEN - All HR zones must be configurable

// BAD:
if heartRate > 170 { // NEVER hardcode
    showHighIntensityWarning()
}

let workZone = 170 // NEVER

// GOOD:
struct HeartRateZone: Codable, Equatable {
    let targetBPM: Int
    let toleranceBPM: Int

    var range: ClosedRange<Int> {
        (targetBPM - toleranceBPM)...(targetBPM + toleranceBPM)
    }

    func contains(_ bpm: Int) -> Bool {
        range.contains(bpm)
    }
}

// User-configurable with sensible defaults
struct TrainingPlan {
    var workZone: HeartRateZone = HeartRateZone(targetBPM: 170, toleranceBPM: 5)
    var restZone: HeartRateZone = HeartRateZone(targetBPM: 150, toleranceBPM: 10)
}

// Check against user's configured zone:
if plan.workZone.contains(currentHR) {
    // In zone
}
```

### Additional Prohibitions

```swift
// NEVER:
// - Force unwrap optionals in production code (use guard/if-let)
// - Use print() for logging (use os.Logger)
// - Block main thread with synchronous operations
// - Store sensitive data in UserDefaults
// - Use singletons without protocol abstraction
// - Commit API keys or secrets to repo
// - Ignore @MainActor warnings
// - Skip error handling with try!

// BAD:
let data = try! JSONDecoder().decode(Session.self, from: response) // NO

// GOOD:
do {
    let data = try JSONDecoder().decode(Session.self, from: response)
} catch {
    logger.error("Failed to decode session: \(error)")
    throw SessionError.decodingFailed(underlying: error)
}
```

---

## Quick Reference

### Key Files

| File | Purpose |
|------|---------|
| `GarminManager.swift` | BLE connection, HR stream |
| `HealthKitManager.swift` | HealthKit queries/writes |
| `HRDataService.swift` | Unified HR source (Garmin/HealthKit/Simulation) |
| `MetronomeEngine.swift` | Audio playback, mixing |
| `IntervalTimer.swift` | Work/rest phase logic, progressive blocks |
| `TrainingViewModel.swift` | Active session state |
| `TrainingPlan.swift` | Plan model with `WorkBlock[]` for progressive workouts |
| `SessionRepository.swift` | CoreData CRUD |
| `UnifiedMusicController.swift` | Apple Music / Spotify integration |
| `IntervalPro.xcdatamodeld` | Core Data model |

### Common Commands

```bash
# Run tests
xcodebuild test -scheme IntervalPro -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Build for testing
xcodebuild build-for-testing -scheme IntervalPro

# SwiftLint
swiftlint --strict

# Generate coverage report
xcrun xccov view --report Build/Logs/Test/*.xcresult
```

### Environment Variables

```bash
# Required for Spotify SDK testing
SPOTIFY_CLIENT_ID=xxx
SPOTIFY_REDIRECT_URI=intervalpro://callback

# Firebase (from GoogleService-Info.plist)
# Never commit actual values
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-27 | Initial CLAUDE.md |
| 1.1 | 2026-01-29 | Added WorkBlock model for progressive workouts, updated key files |
