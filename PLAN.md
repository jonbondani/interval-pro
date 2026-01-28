# PLAN.md - IntervalPro Development Plan

## Overview

**Project:** IntervalPro iOS
**Timeline:** Q1 2026 (12 weeks)
**Total Estimated Hours:** 480h
**Team:** 2 iOS devs + 0.5 QA

---

## Milestones Summary

| Milestone | Target Date | Key Deliverable |
|-----------|-------------|-----------------|
| **M1: MVP Timer** | Week 4 | Working interval timer with local HR simulation |
| **M2: Full Integration** | Week 8 | Garmin + HealthKit + Audio working end-to-end |
| **M3: App Store Ready** | Week 12 | Submitted to App Store Review |

---

## Phase 1: Project Setup & Architecture

**Duration:** Week 1
**Total Hours:** 32h
**Dependencies:** None

### 1.1 Xcode Project Initialization

- [ ] **1.1.1** Create Xcode project with SwiftUI lifecycle
  - **Hours:** 2h
  - **Subtasks:**
    - [ ] New project: IntervalPro, iOS 16.0 minimum
    - [ ] Configure Bundle ID: `com.intervalpro.app`
    - [ ] Set up Development Team & signing
    - [ ] Configure app icons and launch screen placeholder
  - **Acceptance Criteria:**
    - Project builds and runs on simulator
    - SwiftUI App lifecycle (`@main` entry point)
    - No UIKit AppDelegate

- [ ] **1.1.2** Configure project structure (feature-based)
  - **Hours:** 3h
  - **Subtasks:**
    - [ ] Create folder structure per CLAUDE.md architecture
    - [ ] Set up group references (not folder references)
    - [ ] Create placeholder files for each module
  - **Acceptance Criteria:**
    ```
    IntervalPro/
    ├── App/
    ├── Features/{Training,Plans,Progress,Settings}/
    ├── Core/{Bluetooth,Health,Audio,Persistence}/
    ├── Shared/{Extensions,Components,Utilities}/
    └── Tests/{UnitTests,UITests}/
    ```

- [ ] **1.1.3** Add SwiftLint configuration
  - **Hours:** 1h
  - **Subtasks:**
    - [ ] Install SwiftLint via SPM or Homebrew
    - [ ] Create `.swiftlint.yml` with project rules
    - [ ] Add build phase script
  - **Acceptance Criteria:**
    - Lint runs on every build
    - Rules enforce CLAUDE.md style guidelines

### 1.2 Dependency Management

- [ ] **1.2.1** Configure Swift Package Manager
  - **Hours:** 2h
  - **Subtasks:**
    - [ ] Add Firebase Analytics SDK
    - [ ] Add Firebase Crashlytics SDK
    - [ ] Add Spotify iOS SDK (conditional)
  - **Acceptance Criteria:**
    - All packages resolve without conflicts
    - Packages pinned to specific versions
  - **Dependencies:** 1.1.1

- [ ] **1.2.2** Set up build configurations
  - **Hours:** 2h
  - **Subtasks:**
    - [ ] Create Debug, Release, TestFlight schemes
    - [ ] Configure environment-specific variables
    - [ ] Set up xcconfig files
  - **Acceptance Criteria:**
    - Different bundle IDs per environment
    - API endpoints configurable per scheme

### 1.3 Core Data Stack

- [ ] **1.3.1** Design Core Data model
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create `IntervalPro.xcdatamodeld`
    - [ ] Define entities: `TrainingPlan`, `TrainingSession`, `IntervalRecord`, `HRSample`
    - [ ] Set up relationships and constraints
    - [ ] Configure encryption for sensitive data
  - **Acceptance Criteria:**
    - Model matches PRD data structures
    - Lightweight migration enabled
    - Store encrypted with `NSPersistentStoreFileProtectionKey`
  - **Dependencies:** 1.1.2

- [ ] **1.3.2** Implement CoreDataStack manager
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create `CoreDataStack.swift` with async/await
    - [ ] Implement container initialization
    - [ ] Add save/fetch/delete operations
    - [ ] Create background context handling
  - **Acceptance Criteria:**
    - Thread-safe operations
    - Error handling for all CRUD
    - Unit tests pass (min 3 tests)
  - **Dependencies:** 1.3.1

### 1.4 Base Architecture

- [ ] **1.4.1** Create protocol abstractions
  - **Hours:** 3h
  - **Subtasks:**
    - [ ] `GarminManaging` protocol
    - [ ] `HealthKitManaging` protocol
    - [ ] `AudioEngineProtocol`
    - [ ] `SessionRepositoryProtocol`
  - **Acceptance Criteria:**
    - All managers have protocol abstraction
    - Protocols support dependency injection
  - **Dependencies:** 1.1.2

- [ ] **1.4.2** Set up logging infrastructure
  - **Hours:** 2h
  - **Subtasks:**
    - [ ] Configure `os.Logger` subsystems
    - [ ] Create logging categories (bluetooth, health, audio, ui)
    - [ ] Add privacy-safe logging helpers
  - **Acceptance Criteria:**
    - No `print()` statements in codebase
    - HR values redacted in logs
  - **Dependencies:** 1.1.2

- [ ] **1.4.3** Create base ViewModels and navigation
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Implement `NavigationRouter` for app navigation
    - [ ] Create base `ViewModel` observable pattern
    - [ ] Set up `@EnvironmentObject` dependencies
  - **Acceptance Criteria:**
    - Navigation works between main tabs
    - ViewModels properly `@MainActor` annotated
  - **Dependencies:** 1.4.1

- [ ] **1.4.4** Write initial unit tests structure
  - **Hours:** 5h
  - **Subtasks:**
    - [ ] Configure test target with async support
    - [ ] Create mock factories for all protocols
    - [ ] Write CoreDataStack tests
    - [ ] Write navigation tests
  - **Acceptance Criteria:**
    - Test target builds and runs
    - Mocks available for all Core protocols
    - 100% coverage on CoreDataStack
  - **Dependencies:** 1.3.2, 1.4.1

---

## Phase 2: HealthKit & Garmin BLE Integration

**Duration:** Weeks 2-3
**Total Hours:** 80h
**Dependencies:** Phase 1 complete

### 2.1 HealthKit Integration

- [ ] **2.1.1** Configure HealthKit entitlements
  - **Hours:** 2h
  - **Subtasks:**
    - [ ] Enable HealthKit capability in Xcode
    - [ ] Add required Info.plist descriptions
    - [ ] Configure clinical data access (if needed)
  - **Acceptance Criteria:**
    - HealthKit entitlement added
    - Privacy descriptions in Spanish/English
  - **Dependencies:** 1.1.1

- [ ] **2.1.2** Implement HealthKitManager - Authorization
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create `HealthKitManager.swift`
    - [ ] Implement authorization request flow
    - [ ] Handle partial authorization scenarios
    - [ ] Store authorization state
  - **Acceptance Criteria:**
    - Clean authorization UI flow
    - Handles denied permissions gracefully
    - Unit tests for all auth states
  - **Dependencies:** 2.1.1, 1.4.1

- [ ] **2.1.3** Implement HR query and streaming
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Query historical HR samples
    - [ ] Set up HKObserverQuery for real-time HR
    - [ ] Create `AnyPublisher<Int, Never>` stream
    - [ ] Handle background delivery
  - **Acceptance Criteria:**
    - Real-time HR updates within 2s latency
    - Historical queries return last 30 days
    - Works in background mode
  - **Dependencies:** 2.1.2

- [ ] **2.1.4** Implement workout session write
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Create HKWorkout builder
    - [ ] Add HR samples to workout
    - [ ] Add route data (GPS) to workout
    - [ ] Handle workout pause/resume/end
  - **Acceptance Criteria:**
    - Workouts appear in Apple Health
    - All intervals recorded as laps
    - Route visible on map
  - **Dependencies:** 2.1.3

- [ ] **2.1.5** Write HealthKit integration tests
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Mock HKHealthStore for unit tests
    - [ ] Test authorization flows
    - [ ] Test sample queries
    - [ ] Test workout writing
  - **Acceptance Criteria:**
    - 90% coverage on HealthKitManager
    - All edge cases tested
  - **Dependencies:** 2.1.4

### 2.2 Garmin Bluetooth Integration

- [ ] **2.2.1** Configure Bluetooth entitlements
  - **Hours:** 1h
  - **Subtasks:**
    - [ ] Enable Bluetooth capability
    - [ ] Add Info.plist descriptions
    - [ ] Configure background modes
  - **Acceptance Criteria:**
    - Bluetooth permissions configured
    - Background scanning enabled
  - **Dependencies:** 1.1.1

- [ ] **2.2.2** Implement CBCentralManager setup
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create `GarminManager.swift`
    - [ ] Initialize CBCentralManager
    - [ ] Implement state machine for connection
    - [ ] Handle Bluetooth power states
  - **Acceptance Criteria:**
    - Proper state handling (off/on/unauthorized)
    - Published connection state
  - **Dependencies:** 2.2.1, 1.4.1

- [ ] **2.2.3** Implement device scanning and discovery
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Scan for Garmin devices (HR service UUID 0x180D)
    - [ ] Filter by device name patterns
    - [ ] Display discovered devices
    - [ ] Remember paired device
  - **Acceptance Criteria:**
    - Discovers Garmin Fenix within 10s
    - Shows device name and signal strength
    - Persists last connected device
  - **Dependencies:** 2.2.2

- [ ] **2.2.4** Implement device connection
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Connect to selected peripheral
    - [ ] Discover services (0x180D HR)
    - [ ] Subscribe to HR characteristic (0x2A37)
    - [ ] Parse HR data packets
  - **Acceptance Criteria:**
    - Stable connection maintained
    - HR updates every 1 second
    - Correct BPM parsing (uint8/uint16)
  - **Dependencies:** 2.2.3

- [ ] **2.2.5** Implement reconnection logic
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Detect disconnection events
    - [ ] Implement exponential backoff retry
    - [ ] Maximum 3 retry attempts
    - [ ] Fallback to HealthKit on failure
  - **Acceptance Criteria:**
    - Auto-reconnect within 10s of disconnect
    - User notified of fallback
    - No UI freeze during reconnection
  - **Dependencies:** 2.2.4, 2.1.3

- [ ] **2.2.6** Implement AutoLap command
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Research Garmin-specific characteristics
    - [ ] Implement lap marker write
    - [ ] Sync with interval phase changes
    - [ ] Handle unsupported devices
  - **Acceptance Criteria:**
    - Lap marked on Garmin when phase changes
    - Works with Fenix 5/6/7
    - Graceful fallback if unsupported
  - **Dependencies:** 2.2.4

- [ ] **2.2.7** Implement additional metrics (pace, speed, cadence)
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Discover running dynamics service
    - [ ] Parse pace/speed data
    - [ ] Parse cadence data
    - [ ] Combine with CoreLocation as backup
  - **Acceptance Criteria:**
    - Pace displayed in min/km
    - Speed in km/h
    - Fallback to iPhone GPS if Garmin unavailable
  - **Dependencies:** 2.2.4

- [ ] **2.2.8** Write Bluetooth integration tests
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Create CBCentralManager mock
    - [ ] Create CBPeripheral mock
    - [ ] Test connection state machine
    - [ ] Test reconnection logic
    - [ ] Test data parsing
  - **Acceptance Criteria:**
    - 85% coverage on GarminManager
    - All state transitions tested
  - **Dependencies:** 2.2.5, 2.2.6, 2.2.7

### 2.3 HR Data Pipeline

- [ ] **2.3.1** Create unified HR stream
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Create `HRDataService.swift`
    - [ ] Merge Garmin + HealthKit streams
    - [ ] Prioritize Garmin when available
    - [ ] Add data smoothing (outlier rejection)
  - **Acceptance Criteria:**
    - Single `AnyPublisher<HRSample, Never>` for UI
    - Automatic source switching
    - Filters impossible values (< 40, > 220)
  - **Dependencies:** 2.1.3, 2.2.4

- [ ] **2.3.2** Implement HR zone detection
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create `HRZoneCalculator.swift`
    - [ ] Compare current HR to target zone
    - [ ] Calculate time in zone metrics
    - [ ] Publish zone status
  - **Acceptance Criteria:**
    - Zone detection < 100ms latency
    - Supports user-configured zones (not hardcoded)
    - Includes tolerance band
  - **Dependencies:** 2.3.1

---

## Phase 3: Interval Timer & Metronome

**Duration:** Weeks 4-5
**Total Hours:** 72h
**Dependencies:** Phase 2 complete

### 3.1 Interval Timer Engine

- [ ] **3.1.1** Design timer state machine
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Define `IntervalPhase` enum (idle, warmup, work, rest, cooldown, complete)
    - [ ] Define `TimerState` (paused, running, stopped)
    - [ ] Create state transition diagram
    - [ ] Document edge cases
  - **Acceptance Criteria:**
    - All states and transitions documented
    - No invalid state transitions possible
  - **Dependencies:** 1.4.1

- [ ] **3.1.2** Implement IntervalTimer core
  - **Hours:** 12h
  - **Subtasks:**
    - [ ] Create `IntervalTimer.swift`
    - [ ] Implement high-precision timer (CADisplayLink or Timer)
    - [ ] Track elapsed time per phase
    - [ ] Handle phase transitions
    - [ ] Support pause/resume
  - **Acceptance Criteria:**
    - Timer accurate to 100ms
    - Phase transitions trigger callbacks
    - Pause preserves exact state
    - Works in background
  - **Dependencies:** 3.1.1

- [ ] **3.1.3** Implement series tracking
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Track current series number
    - [ ] Calculate remaining series
    - [ ] Store per-series metrics
    - [ ] Handle early termination
  - **Acceptance Criteria:**
    - Series count accurate
    - Metrics stored per interval
    - Can end early with partial data saved
  - **Dependencies:** 3.1.2

- [ ] **3.1.4** Integrate with HR zone feedback
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Subscribe to HR stream
    - [ ] Calculate real-time zone compliance
    - [ ] Trigger alerts for zone deviation
    - [ ] Update UI indicators
  - **Acceptance Criteria:**
    - Zone compliance calculated every second
    - Visual indicator updates instantly
    - Haptic feedback when leaving zone
  - **Dependencies:** 3.1.2, 2.3.2

- [ ] **3.1.5** Write interval timer tests
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Test phase transitions
    - [ ] Test pause/resume accuracy
    - [ ] Test series completion
    - [ ] Test edge cases (very short intervals, many series)
  - **Acceptance Criteria:**
    - 95% coverage on IntervalTimer
    - Timing tests with tolerance
  - **Dependencies:** 3.1.4

---

### 3.2 Audio Metronome Engine

- [ ] **3.2.1** Configure AVAudioSession for mixing
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Set category `.playback`
    - [ ] Set mode `.default`
    - [ ] Configure options `[.mixWithOthers, .duckOthers]`
    - [ ] Handle audio interruptions (calls, Siri)
  - **Acceptance Criteria:**
    - Audio plays over other apps
    - Music ducks during announcements
    - Resumes after phone call
  - **Dependencies:** 1.1.1

- [ ] **3.2.2** Implement metronome sound playback
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Create `MetronomeEngine.swift`
    - [ ] Load audio samples (click, beep, woodblock)
    - [ ] Implement BPM-accurate scheduling
    - [ ] Use AVAudioPlayer or AVAudioEngine
  - **Acceptance Criteria:**
    - Clicks at exact BPM (150-190)
    - No audio drift over 30 minutes
    - Volume independently adjustable
  - **Dependencies:** 3.2.1

- [ ] **3.2.3** Implement voice announcements
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Create `VoiceAnnouncementService.swift`
    - [ ] Configure AVSpeechSynthesizer
    - [ ] Define announcement triggers (phase change, time warnings)
    - [ ] Support Spanish/English
  - **Acceptance Criteria:**
    - Clear voice at outdoor volume
    - Announcements: "Iniciando trabajo", "30 segundos", "Descanso"
    - Language matches device setting
  - **Dependencies:** 3.2.1

- [ ] **3.2.4** Implement audio ducking for music
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Detect voice announcement start
    - [ ] Lower music volume temporarily
    - [ ] Restore volume after announcement
    - [ ] Smooth volume transitions
  - **Acceptance Criteria:**
    - Music volume drops 70% during voice
    - Transition smooth (200ms fade)
    - No audio artifacts
  - **Dependencies:** 3.2.3

- [ ] **3.2.5** Create metronome configuration UI
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] BPM slider (150-190)
    - [ ] Sound type picker
    - [ ] Volume slider
    - [ ] Enable/disable toggle
  - **Acceptance Criteria:**
    - Settings persist
    - Live preview of sound
    - Accessible controls
  - **Dependencies:** 3.2.2

- [ ] **3.2.6** Write audio engine tests
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Test BPM accuracy
    - [ ] Test audio session configuration
    - [ ] Test interruption handling
    - [ ] Test voice announcements
  - **Acceptance Criteria:**
    - Audio tests with mocked AVFoundation
    - Timing accuracy verified
  - **Dependencies:** 3.2.4

---

## Milestone 1: MVP Timer

**Target:** End of Week 5
**Deliverables:**
- [ ] Working interval timer with configurable work/rest/series
- [ ] Simulated HR data (for testing without Garmin)
- [ ] Basic metronome audio
- [ ] Voice announcements for phase changes
- [ ] Minimal UI showing timer and HR

**Demo Criteria:**
- [ ] Complete 4x3min workout with audio feedback
- [ ] Timer accurate within 1 second over 30 minutes
- [ ] Audio plays over Spotify without interruption

---

## Phase 4: Music Overlay Integration

**Duration:** Week 6
**Total Hours:** 40h
**Dependencies:** Phase 3 complete

### 4.1 Apple Music Integration

- [x] **4.1.1** Configure MusicKit
  - **Hours:** 2h
  - **Subtasks:**
    - [x] Add MusicKit capability
    - [x] Request MusicKit authorization
    - [x] Configure Info.plist
  - **Acceptance Criteria:**
    - MusicKit authorized
    - Can access user's library
  - **Dependencies:** 1.1.1
  - **Completed:** 2026-01-28 - Created AppleMusicController.swift

- [x] **4.1.2** Implement music playback control
  - **Hours:** 6h
  - **Subtasks:**
    - [x] Create `MusicPlayerService.swift`
    - [x] Get now playing info
    - [x] Implement play/pause/skip
    - [x] Display current track
  - **Acceptance Criteria:**
    - Controls work during workout
    - Track info displays correctly
  - **Dependencies:** 4.1.1
  - **Completed:** 2026-01-28 - AppleMusicController with MPMusicPlayerController

### 4.2 Spotify Integration

- [x] **4.2.1** Configure Spotify SDK
  - **Hours:** 4h
  - **Subtasks:**
    - [x] Add Spotify SDK via SPM
    - [x] Configure redirect URI
    - [x] Implement OAuth flow
    - [x] Store tokens in Keychain
  - **Acceptance Criteria:**
    - Spotify login works
    - Tokens persist and refresh
  - **Dependencies:** 1.2.1
  - **Completed:** 2026-01-28 - Created SpotifyController.swift with OAuth flow

- [x] **4.2.2** Implement Spotify playback control
  - **Hours:** 8h
  - **Subtasks:**
    - [x] Connect to Spotify app
    - [x] Get playback state
    - [x] Implement play/pause/skip
    - [x] Handle disconnection
  - **Acceptance Criteria:**
    - Controls work without leaving app
    - Shows album art and track
  - **Dependencies:** 4.2.1
  - **Completed:** 2026-01-28 - SpotifyController with AppRemote integration

### 4.3 Unified Music Controller

- [x] **4.3.1** Create unified music interface
  - **Hours:** 6h
  - **Subtasks:**
    - [x] Create `MusicControllerProtocol`
    - [x] Abstract Apple Music and Spotify
    - [x] Auto-detect active player
    - [x] Handle no music playing
  - **Acceptance Criteria:**
    - Single UI for both services
    - Seamless switching
  - **Dependencies:** 4.1.2, 4.2.2
  - **Completed:** 2026-01-28 - Created UnifiedMusicController.swift

- [x] **4.3.2** Create mini player UI component
  - **Hours:** 6h
  - **Subtasks:**
    - [x] Design mini player bar
    - [x] Show track info
    - [x] Add playback controls
    - [x] Volume slider (independent of metronome)
  - **Acceptance Criteria:**
    - Non-intrusive during workout
    - Thumb-friendly controls
    - SwiftUI component
  - **Dependencies:** 4.3.1
  - **Completed:** 2026-01-28 - Created MiniPlayerView.swift with FullPlayerSheet

- [x] **4.3.3** Write music integration tests
  - **Hours:** 8h
  - **Subtasks:**
    - [x] Mock MusicKit
    - [x] Mock Spotify SDK
    - [x] Test control flows
    - [x] Test error handling
  - **Acceptance Criteria:**
    - 80% coverage on music services
  - **Dependencies:** 4.3.2
  - **Completed:** 2026-01-28 - Created MusicControllerTests.swift, MiniPlayerViewTests.swift

---

## Phase 5: Historical Analysis & Best Session

**Duration:** Week 7
**Total Hours:** 48h
**Dependencies:** Phases 1-4 complete

### 5.1 Session Persistence

- [ ] **5.1.1** Implement SessionRepository
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Create `SessionRepository.swift`
    - [ ] Implement save session
    - [ ] Implement fetch sessions (paginated)
    - [ ] Implement delete session
  - **Acceptance Criteria:**
    - CRUD operations work
    - Pagination for large datasets
    - Async/await interface
  - **Dependencies:** 1.3.2

- [ ] **5.1.2** Save completed workout session
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Capture all interval data
    - [ ] Calculate aggregate metrics
    - [ ] Store HR samples
    - [ ] Link to training plan
  - **Acceptance Criteria:**
    - Session saved on completion
    - All PRD metrics captured
  - **Dependencies:** 5.1.1, 3.1.4

### 5.2 Best Session Algorithm

- [ ] **5.2.1** Implement session scoring
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Create `SessionScoringService.swift`
    - [ ] Implement scoring formula from PRD
    - [ ] Weight factors: TimeInZone(40%), Pace(30%), Completion(20%), Distance(10%)
    - [ ] Normalize scores 0-100
  - **Acceptance Criteria:**
    - Consistent scoring across sessions
    - Formula matches PRD specification
  - **Dependencies:** 5.1.2

- [ ] **5.2.2** Implement best session matching
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Create `BestSessionMatcher.swift`
    - [ ] Filter sessions by similar config (±10 BPM, ±1 series, ±30s duration)
    - [ ] Return highest scored match
    - [ ] Handle no matching sessions
  - **Acceptance Criteria:**
    - Finds best comparable session
    - Matching criteria from PRD
  - **Dependencies:** 5.2.1

- [ ] **5.2.3** Implement real-time comparison
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Compare current vs best during workout
    - [ ] Calculate delta per interval
    - [ ] Project final score
    - [ ] Publish comparison updates
  - **Acceptance Criteria:**
    - Updates every interval
    - Shows +/- vs best
    - Prediction accuracy ±5%
  - **Dependencies:** 5.2.2, 3.1.4

### 5.3 Progress Analytics

- [ ] **5.3.1** Implement weekly statistics
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Calculate weekly aggregates
    - [ ] Sessions count, total distance, avg score
    - [ ] Compare week over week
    - [ ] Identify trends
  - **Acceptance Criteria:**
    - Stats calculate correctly
    - Handles incomplete weeks
  - **Dependencies:** 5.1.1

- [ ] **5.3.2** Create progress chart data
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Format data for Swift Charts
    - [ ] Score trend over time
    - [ ] Time in zone trend
    - [ ] Pace improvement
  - **Acceptance Criteria:**
    - Data ready for visualization
    - Handles gaps in data
  - **Dependencies:** 5.3.1

---

## Phase 6: Configuration & UI

**Duration:** Weeks 8-10
**Total Hours:** 96h
**Dependencies:** Phases 1-5 complete

### 6.1 Training Plan Configuration

- [ ] **6.1.1** Implement plan builder view
  - **Hours:** 12h
  - **Subtasks:**
    - [ ] Create `PlanBuilderView.swift`
    - [ ] HR zone selectors (160/170/180)
    - [ ] Duration pickers
    - [ ] Series stepper
    - [ ] Warm-up/cool-down toggles
  - **Acceptance Criteria:**
    - All options from PRD configurable
    - Form validation
    - SwiftUI previews for all states
  - **Dependencies:** 1.3.1

- [ ] **6.1.2** Implement plan templates
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Create 3 default templates (Beginner, Intermediate, Advanced)
    - [ ] Quick start from template
    - [ ] Template descriptions
  - **Acceptance Criteria:**
    - Templates match PRD
    - One-tap start
  - **Dependencies:** 6.1.1

- [ ] **6.1.3** Implement plan persistence
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Save custom plans to Core Data
    - [ ] Load saved plans
    - [ ] Edit existing plans
    - [ ] Delete plans
  - **Acceptance Criteria:**
    - Plans persist across app restarts
    - Max 10 plans (free tier)
  - **Dependencies:** 6.1.1, 1.3.2

### 6.2 Training Screen

- [ ] **6.2.1** Implement active training view
  - **Hours:** 16h
  - **Subtasks:**
    - [ ] Create `TrainingView.swift`
    - [ ] Large HR display (72pt font)
    - [ ] Timer countdown
    - [ ] Phase indicator
    - [ ] Series progress dots
    - [ ] Pace and distance
    - [ ] Zone indicator bar
  - **Acceptance Criteria:**
    - Matches wireframe from PRD
    - Readable in bright sunlight
    - Responsive to all iPhone sizes
  - **Dependencies:** 3.1.4, 2.3.2

- [ ] **6.2.2** Implement pause/resume controls
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Large pause button
    - [ ] Resume confirmation
    - [ ] End workout option
    - [ ] Discard confirmation
  - **Acceptance Criteria:**
    - Easy to hit while running
    - 44pt minimum tap target
  - **Dependencies:** 6.2.1

- [ ] **6.2.3** Implement vs best session display
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Show delta vs best
    - [ ] Color coding (green ahead, red behind)
    - [ ] Compact display during workout
  - **Acceptance Criteria:**
    - Non-distracting but visible
    - Updates per interval
  - **Dependencies:** 6.2.1, 5.2.3

### 6.3 Summary Screen

- [ ] **6.3.1** Implement session summary view
  - **Hours:** 12h
  - **Subtasks:**
    - [ ] Create `SessionSummaryView.swift`
    - [ ] Score display (celebration if PR)
    - [ ] Metrics summary
    - [ ] Interval breakdown table
    - [ ] Time in zone chart
    - [ ] vs previous best comparison
  - **Acceptance Criteria:**
    - Matches wireframe from PRD
    - Animated score reveal
    - Confetti on PR
  - **Dependencies:** 5.1.2, 5.2.1

- [ ] **6.3.2** Implement share functionality
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Generate share card image
    - [ ] System share sheet
    - [ ] Export to Strava
    - [ ] Export GPX/TCX
  - **Acceptance Criteria:**
    - Branded share card
    - Strava upload works
    - Standard file exports
  - **Dependencies:** 6.3.1

### 6.4 Progress Screen

- [ ] **6.4.1** Implement progress dashboard
  - **Hours:** 10h
  - **Subtasks:**
    - [ ] Create `ProgressView.swift`
    - [ ] Weekly summary card
    - [ ] Score trend chart (Swift Charts)
    - [ ] Time in zone trend chart
    - [ ] Personal records list
  - **Acceptance Criteria:**
    - Charts render smoothly
    - Matches wireframe
    - Handles empty state
  - **Dependencies:** 5.3.2

- [ ] **6.4.2** Implement session history list
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Session list with lazy loading
    - [ ] Filter by plan type
    - [ ] Delete with swipe
    - [ ] Navigate to detail
  - **Acceptance Criteria:**
    - Smooth scrolling
    - Filters work correctly
  - **Dependencies:** 5.1.1

### 6.5 Settings & Onboarding

- [ ] **6.5.1** Implement settings screen
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Garmin connection status/manage
    - [ ] HealthKit permissions
    - [ ] Audio settings (metronome, voice)
    - [ ] Music service selection
    - [ ] Data export/delete
  - **Acceptance Criteria:**
    - All CLAUDE.md privacy requirements
    - Clear connection status
  - **Dependencies:** 2.2.2, 2.1.2, 3.2.5

- [ ] **6.5.2** Implement onboarding flow
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Welcome screen
    - [ ] HealthKit permission request
    - [ ] Garmin pairing guide
    - [ ] First plan creation
  - **Acceptance Criteria:**
    - Completed in < 2 minutes
    - Can skip Garmin for later
    - Tracks completion in analytics
  - **Dependencies:** 6.5.1

---

## Milestone 2: Full Integration

**Target:** End of Week 10
**Deliverables:**
- [ ] All UI screens implemented per wireframes
- [ ] Garmin + HealthKit integration working
- [ ] Audio metronome + voice + music overlay working
- [ ] Best session matching and comparison
- [ ] Session history and progress charts
- [ ] Export and share functionality

**Demo Criteria:**
- [ ] Complete end-to-end workout with Garmin
- [ ] View progress over multiple sessions
- [ ] Share workout to Strava

---

## Phase 7: Testing & Deployment

**Duration:** Weeks 11-12
**Total Hours:** 64h
**Dependencies:** Phase 6 complete

### 7.1 Comprehensive Testing

- [ ] **7.1.1** Unit test coverage audit
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Run coverage report
    - [ ] Identify gaps (target 80% business logic)
    - [ ] Write missing tests
    - [ ] Fix flaky tests
  - **Acceptance Criteria:**
    - 80%+ coverage on Core/
    - 70%+ coverage on Features/ViewModels
    - All tests pass consistently
  - **Dependencies:** All phases

- [ ] **7.1.2** Integration testing
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Test HealthKit write flow
    - [ ] Test Garmin connection flow
    - [ ] Test full workout completion
    - [ ] Test data persistence
  - **Acceptance Criteria:**
    - Critical paths tested
    - No data loss scenarios
  - **Dependencies:** 7.1.1

- [ ] **7.1.3** UI testing
  - **Hours:** 8h
  - **Subtasks:**
    - [ ] Test onboarding flow
    - [ ] Test plan creation
    - [ ] Test workout start/complete
    - [ ] Test navigation
  - **Acceptance Criteria:**
    - Happy paths automated
    - Tests run on CI
  - **Dependencies:** 7.1.1

- [ ] **7.1.4** Performance testing
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] Profile memory usage during workout
    - [ ] Profile battery consumption
    - [ ] Profile Core Data queries
    - [ ] Optimize hot paths
  - **Acceptance Criteria:**
    - < 150MB memory during workout
    - < 10% battery per 30 min workout
    - No UI jank (60fps maintained)
  - **Dependencies:** 7.1.1

### 7.2 Beta Testing

- [ ] **7.2.1** Prepare TestFlight build
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Configure App Store Connect
    - [ ] Upload build
    - [ ] Configure beta groups
    - [ ] Write release notes
  - **Acceptance Criteria:**
    - Build approved by Apple
    - Ready for external testing
  - **Dependencies:** 7.1.3

- [ ] **7.2.2** Conduct beta test (50 users)
  - **Hours:** 8h (across 2 weeks)
  - **Subtasks:**
    - [ ] Recruit beta testers
    - [ ] Provide feedback channels
    - [ ] Monitor Crashlytics
    - [ ] Collect qualitative feedback
  - **Acceptance Criteria:**
    - 50 active testers
    - < 1% crash rate
    - NPS feedback collected
  - **Dependencies:** 7.2.1

- [ ] **7.2.3** Bug fix sprint
  - **Hours:** 12h
  - **Subtasks:**
    - [ ] Triage beta feedback
    - [ ] Fix critical bugs
    - [ ] Fix high-priority UX issues
    - [ ] Release updated beta
  - **Acceptance Criteria:**
    - All P0 bugs fixed
    - P1 bugs triaged
  - **Dependencies:** 7.2.2

### 7.3 App Store Submission

- [ ] **7.3.1** Prepare App Store assets
  - **Hours:** 6h
  - **Subtasks:**
    - [ ] App icon (all sizes)
    - [ ] Screenshots (6.5", 5.5", iPad)
    - [ ] App preview video
    - [ ] Description (Spanish/English)
    - [ ] Keywords optimization
  - **Acceptance Criteria:**
    - All required assets ready
    - Compelling screenshots
  - **Dependencies:** 7.2.3

- [ ] **7.3.2** Complete App Store submission
  - **Hours:** 4h
  - **Subtasks:**
    - [ ] Fill all metadata
    - [ ] Configure pricing (Free + IAP)
    - [ ] Submit for review
    - [ ] Prepare rejection response plan
  - **Acceptance Criteria:**
    - Submission complete
    - No obvious rejection risks
  - **Dependencies:** 7.3.1

- [ ] **7.3.3** Address App Review feedback
  - **Hours:** Reserved (variable)
  - **Subtasks:**
    - [ ] Respond to rejection (if any)
    - [ ] Implement required changes
    - [ ] Resubmit
  - **Acceptance Criteria:**
    - App approved
  - **Dependencies:** 7.3.2

---

## Milestone 3: App Store Ready

**Target:** End of Week 12
**Deliverables:**
- [ ] App submitted to App Store
- [ ] All critical bugs fixed
- [ ] Beta testing complete (50 users)
- [ ] 80% test coverage achieved
- [ ] Performance benchmarks met

**Launch Criteria:**
- [ ] < 1% crash rate
- [ ] 85% session completion rate
- [ ] Positive beta feedback (NPS > 30)

---

## Risk Register

| ID | Risk | Probability | Impact | Mitigation | Owner |
|----|------|-------------|--------|------------|-------|
| R1 | Garmin BLE API undocumented | High | High | Early prototype, fallback to HealthKit only | Dev 1 |
| R2 | Apple rejects for HealthKit usage | Medium | High | Follow guidelines strictly, detailed justification | Dev 2 |
| R3 | Audio latency in metronome | Medium | Medium | Use low-latency AVAudioEngine, extensive testing | Dev 1 |
| R4 | Spotify SDK rate limits | Low | Medium | Cache playback state, graceful degradation | Dev 2 |
| R5 | Background mode battery drain | Medium | Medium | Optimize polling intervals, test on real devices | Dev 1 |
| R6 | Beta tester recruitment | Medium | Low | Leverage running communities, offer premium | PM |
| R7 | Scope creep | High | Medium | Strict MVP definition, defer to v1.1 | PM |

### Contingency Plans

**If Garmin AutoLap fails (R1):**
- Remove AutoLap feature from v1.0
- Document as v1.1 enhancement
- Focus on HR streaming only

**If Apple rejects (R2):**
- Prepare detailed justification document
- Remove clinical claims from description
- Emphasize fitness (not medical) use case

**If audio latency unacceptable (R3):**
- Switch to pre-recorded voice clips
- Reduce metronome to simple vibrations
- Investigate AudioToolbox for lower latency

---

## Dependencies Summary

```
Phase 1 ──┬──> Phase 2 ──┬──> Phase 3 ──> Phase 4
          │              │
          │              └──> Phase 5
          │
          └──> Phase 6 (after Phase 5)
                    │
                    └──> Phase 7
```

### External Dependencies

| Dependency | Required By | Risk | Mitigation |
|------------|-------------|------|------------|
| Apple Developer Account | Phase 7 | Low | Already available |
| Garmin Developer Account | Phase 2 | Low | Register early |
| Spotify Developer Account | Phase 4 | Low | Register in Phase 1 |
| TestFlight Testers | Phase 7 | Medium | Recruit during Phase 6 |

---

## Progress Tracking

### Weekly Check-ins

- **Monday:** Sprint planning, blockers review
- **Wednesday:** Mid-week sync, demo progress
- **Friday:** Sprint review, update PLAN.md checkboxes

### Status Legend

- [ ] Not started
- [~] In progress
- [x] Complete
- [!] Blocked
- [-] Descoped

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-27 | 1.0 | Initial plan created |
| 2026-01-28 | 1.1 | Phase 1 complete: Project setup, Core Data, architecture |
| 2026-01-28 | 1.2 | Phase 2 complete: HealthKit, Garmin BLE, HR data pipeline |
| 2026-01-28 | 1.3 | Phase 3 complete: IntervalTimer, MetronomeEngine, TrainingViewModel |
| 2026-01-28 | 1.4 | Phase 4 complete: Music integration (Apple Music, Spotify, UnifiedController) |

---

*Last updated: 2026-01-27*
*Next review: Weekly*
