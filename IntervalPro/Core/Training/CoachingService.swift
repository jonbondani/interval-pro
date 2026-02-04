import Foundation
import Combine

/// Service that provides real-time coaching feedback based on cadence and pace
/// Combines cadence (SPM) and pace (sec/km) analysis to provide unified coaching
@MainActor
final class CoachingService: ObservableObject {
    // MARK: - Singleton
    static let shared = CoachingService()

    // MARK: - Published State
    @Published private(set) var currentStatus: CoachingStatus?
    @Published private(set) var lastInstruction: CoachingInstruction = .maintainPace

    // MARK: - Configuration
    var announcementInterval: TimeInterval = 15  // Minimum seconds between announcements
    var isEnabled: Bool = true

    // MARK: - Dependencies
    private var audioEngine: AudioEngineProtocol?
    private var musicController: UnifiedMusicController?

    // MARK: - Private State
    private var lastAnnouncementTime: Date = .distantPast
    private var targetZone: HeartRateZone?
    private var recordPace: Double?
    private var isWorkoutRunning: Bool = false

    // MARK: - Init
    private init() {}

    // MARK: - Configuration
    func configure(
        audioEngine: AudioEngineProtocol,
        musicController: UnifiedMusicController
    ) {
        self.audioEngine = audioEngine
        self.musicController = musicController
    }

    func setTargetZone(_ zone: HeartRateZone?) {
        targetZone = zone
    }

    func setRecordPace(_ pace: Double?) {
        recordPace = pace
    }

    func setWorkoutRunning(_ running: Bool) {
        isWorkoutRunning = running
        if !running {
            currentStatus = nil
        }
    }

    // MARK: - Update
    /// Update coaching status with current cadence and pace
    /// Called periodically during workout
    func update(cadence: Int, pace: Double) {
        guard isWorkoutRunning, let zone = targetZone else {
            currentStatus = nil
            return
        }

        // Calculate combined coaching status
        let status = zone.coachingStatus(
            cadence: cadence,
            pace: pace,
            recordPace: recordPace
        )

        currentStatus = status
        lastInstruction = status.primaryInstruction

        // Check if we should announce
        checkAndAnnounce(status: status)
    }

    // MARK: - Announcements
    private func checkAndAnnounce(status: CoachingStatus) {
        guard isEnabled,
              isWorkoutRunning,
              let audioEngine = audioEngine else { return }

        let now = Date()
        let timeSinceLastAnnouncement = now.timeIntervalSince(lastAnnouncementTime)

        // Don't announce too frequently
        guard timeSinceLastAnnouncement >= announcementInterval else { return }

        let instruction = status.primaryInstruction

        // Determine if we need to announce
        let shouldAnnounce: Bool
        switch instruction {
        case .maintainPace:
            // Only occasionally remind to maintain pace
            shouldAnnounce = timeSinceLastAnnouncement >= 30
        case .recordPace:
            // Always announce record pace achievement
            shouldAnnounce = true
        case .speedUpCadence(let diff), .slowDownCadence(let diff):
            // Announce if cadence is significantly off
            shouldAnnounce = diff >= 5
        case .speedUpPace(let diff), .slowDownPace(let diff):
            // Announce if pace is significantly off
            shouldAnnounce = diff >= 10
        }

        if shouldAnnounce {
            lastAnnouncementTime = now
            Task {
                await musicController?.duckForAnnouncement()
                await audioEngine.announceCoachingInstruction(instruction)
                try? await Task.sleep(for: .milliseconds(500))
                await musicController?.restoreFromDuck()
            }
        }
    }

    /// Force an immediate coaching announcement
    func announceNow() async {
        guard let status = currentStatus,
              let audioEngine = audioEngine else { return }

        lastAnnouncementTime = Date()
        await musicController?.duckForAnnouncement()
        await audioEngine.announceCoachingInstruction(status.primaryInstruction)
        try? await Task.sleep(for: .milliseconds(500))
        await musicController?.restoreFromDuck()
    }

    // MARK: - Reset
    func reset() {
        currentStatus = nil
        lastInstruction = .maintainPace
        lastAnnouncementTime = .distantPast
        targetZone = nil
        recordPace = nil
        isWorkoutRunning = false
    }
}
