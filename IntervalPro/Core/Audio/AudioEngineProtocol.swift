import Foundation
import Combine

/// Protocol for audio engine (metronome + voice)
/// Per CLAUDE.md: All managers must have protocol abstraction for DI
protocol AudioEngineProtocol: AnyObject {
    // MARK: - Metronome
    var isMetronomeRunning: Bool { get }
    func startMetronome(bpm: Int, volume: Float, soundType: MetronomeSoundType) throws
    func stopMetronome()
    func updateMetronomeBPM(_ bpm: Int)
    func updateMetronomeVolume(_ volume: Float)

    // MARK: - Voice Announcements
    var isVoiceEnabled: Bool { get set }
    var voiceVolume: Float { get set }
    func announce(_ message: String) async
    func announcePhaseChange(_ phase: IntervalPhase) async
    func announceTimeWarning(secondsRemaining: Int) async
    func announceZoneStatus(_ status: ZoneStatus) async
    func announceCoachingInstruction(_ instruction: CoachingInstruction) async
    func stopVoice()

    // MARK: - Audio Session
    func configureAudioSession() throws
    func deactivateAudioSession()
}

// MARK: - Metronome Sound Types
enum MetronomeSoundType: String, CaseIterable, Identifiable, Codable {
    case click = "click"
    case beep = "beep"
    case woodblock = "woodblock"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .click: return "Click"
        case .beep: return "Beep"
        case .woodblock: return "Madera"
        }
    }

    var fileName: String {
        switch self {
        case .click: return "metronome_click"
        case .beep: return "metronome_beep"
        case .woodblock: return "metronome_woodblock"
        }
    }
}

// MARK: - Metronome Configuration
struct MetronomeConfig: Codable, Equatable {
    var bpm: Int
    var volume: Float
    var soundType: MetronomeSoundType
    var isEnabled: Bool

    static let `default` = MetronomeConfig(
        bpm: 170,
        volume: 0.7,
        soundType: .click,
        isEnabled: true
    )

    // Validate BPM range
    var validatedBPM: Int {
        min(max(bpm, 100), 220)
    }
}

// MARK: - Voice Configuration
struct VoiceConfig: Codable, Equatable {
    var isEnabled: Bool
    var volume: Float
    var language: String

    static let `default` = VoiceConfig(
        isEnabled: true,
        volume: 0.9,
        language: "es-ES"
    )
}

// MARK: - Audio Errors
enum AudioEngineError: LocalizedError {
    case sessionConfigurationFailed
    case audioFileNotFound(String)
    case playbackFailed
    case speechSynthesisFailed

    var errorDescription: String? {
        switch self {
        case .sessionConfigurationFailed:
            return "Error al configurar la sesión de audio."
        case .audioFileNotFound(let name):
            return "Archivo de audio no encontrado: \(name)"
        case .playbackFailed:
            return "Error al reproducir audio."
        case .speechSynthesisFailed:
            return "Error en síntesis de voz."
        }
    }
}

// MARK: - Mock for Testing
final class MockAudioEngine: AudioEngineProtocol {
    var isMetronomeRunning: Bool = false
    var isVoiceEnabled: Bool = true
    var voiceVolume: Float = 0.9

    private(set) var lastAnnouncedMessage: String?
    private(set) var currentBPM: Int = 170
    private(set) var currentVolume: Float = 0.7

    func startMetronome(bpm: Int, volume: Float, soundType: MetronomeSoundType) throws {
        isMetronomeRunning = true
        currentBPM = bpm
        currentVolume = volume
        Log.audio.debug("Mock: Metronome started at \(bpm) BPM")
    }

    func stopMetronome() {
        isMetronomeRunning = false
        Log.audio.debug("Mock: Metronome stopped")
    }

    func updateMetronomeBPM(_ bpm: Int) {
        currentBPM = bpm
    }

    func updateMetronomeVolume(_ volume: Float) {
        currentVolume = volume
    }

    func announce(_ message: String) async {
        lastAnnouncedMessage = message
        Log.audio.debug("Mock: Announced '\(message)'")
    }

    func announcePhaseChange(_ phase: IntervalPhase) async {
        await announce(phase.startAnnouncement)
    }

    func announceTimeWarning(secondsRemaining: Int) async {
        await announce("\(secondsRemaining) segundos")
    }

    func announceZoneStatus(_ status: ZoneStatus) async {
        await announce(status.instruction)
    }

    func announceCoachingInstruction(_ instruction: CoachingInstruction) async {
        await announce(instruction.voiceMessage)
    }

    func stopVoice() {
        Log.audio.debug("Mock: Voice stopped")
    }

    func configureAudioSession() throws {
        Log.audio.debug("Mock: Audio session configured")
    }

    func deactivateAudioSession() {
        Log.audio.debug("Mock: Audio session deactivated")
    }
}
