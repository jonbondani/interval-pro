import AVFoundation
import Combine

/// Audio engine for metronome and voice announcements
/// Per CLAUDE.md: Uses AVAudioSession with mixWithOthers for Spotify/Apple Music overlay
final class MetronomeEngine: NSObject, ObservableObject, AudioEngineProtocol {
    // MARK: - Singleton
    static let shared = MetronomeEngine()

    // MARK: - Published State
    @Published private(set) var isMetronomeRunning: Bool = false
    @Published var isVoiceEnabled: Bool = true
    @Published var voiceVolume: Float = 0.9

    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private var speechSynthesizer: AVSpeechSynthesizer?

    // MARK: - Metronome State
    private var metronomeTimer: Timer?
    private var currentBPM: Int = 170
    private var currentVolume: Float = 0.7
    private var currentSoundType: MetronomeSoundType = .click

    // MARK: - Audio Session
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Constants
    private let duckingVolume: Float = 0.3
    private let normalVolume: Float = 1.0
    private let duckingDuration: TimeInterval = 0.2

    // MARK: - Init
    private override init() {
        super.init()
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer?.delegate = self

        setupNotifications()

        Log.audio.debug("MetronomeEngine initialized")
    }

    deinit {
        stopMetronome()
        deactivateAudioSession()
    }

    // MARK: - Audio Session Configuration
    func configureAudioSession() throws {
        do {
            // Configure for mixing with other audio (Spotify, Apple Music)
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )

            try audioSession.setActive(true)

            Log.audio.info("Audio session configured: playback, mixWithOthers, duckOthers")
        } catch {
            Log.audio.error("Audio session configuration failed: \(error)")
            throw AudioEngineError.sessionConfigurationFailed
        }
    }

    func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            Log.audio.debug("Audio session deactivated")
        } catch {
            Log.audio.warning("Failed to deactivate audio session: \(error)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            Log.audio.debug("Audio interruption began")
            if isMetronomeRunning {
                stopMetronomeTimer()
            }

        case .ended:
            Log.audio.debug("Audio interruption ended")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isMetronomeRunning {
                    startMetronomeTimer()
                }
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged
            Log.audio.debug("Audio route changed: old device unavailable")
        default:
            break
        }
    }

    // MARK: - Metronome
    func startMetronome(bpm: Int, volume: Float, soundType: MetronomeSoundType) throws {
        guard !isMetronomeRunning else {
            updateMetronomeBPM(bpm)
            updateMetronomeVolume(volume)
            return
        }

        try configureAudioSession()
        try loadAudioBuffer(for: soundType)

        currentBPM = bpm
        currentVolume = volume
        currentSoundType = soundType

        setupAudioEngine()
        startMetronomeTimer()

        isMetronomeRunning = true

        Log.audio.info("Metronome started: \(bpm) BPM, volume \(volume), sound \(soundType.rawValue)")
    }

    func stopMetronome() {
        stopMetronomeTimer()

        audioEngine?.stop()
        playerNode?.stop()
        audioEngine = nil
        playerNode = nil

        isMetronomeRunning = false

        Log.audio.info("Metronome stopped")
    }

    func updateMetronomeBPM(_ bpm: Int) {
        guard bpm >= 100 && bpm <= 220 else {
            Log.audio.warning("Invalid BPM: \(bpm), must be 100-220")
            return
        }

        currentBPM = bpm

        if isMetronomeRunning {
            // Restart timer with new interval
            stopMetronomeTimer()
            startMetronomeTimer()
        }

        Log.audio.debug("Metronome BPM updated: \(bpm)")
    }

    func updateMetronomeVolume(_ volume: Float) {
        currentVolume = max(0, min(1, volume))

        Log.audio.debug("Metronome volume updated: \(volume)")
    }

    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = playerNode else { return }

        engine.attach(player)

        if let buffer = audioBuffer {
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        }

        do {
            try engine.start()
            Log.audio.debug("Audio engine started")
        } catch {
            Log.audio.error("Failed to start audio engine: \(error)")
        }
    }

    private func loadAudioBuffer(for soundType: MetronomeSoundType) throws {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "wav") else {
            // Generate synthetic click if file not found
            audioBuffer = generateSyntheticClick()
            Log.audio.debug("Using synthetic click sound")
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)

            if let buffer = audioBuffer {
                try file.read(into: buffer)
                Log.audio.debug("Loaded audio file: \(soundType.fileName)")
            }
        } catch {
            Log.audio.warning("Failed to load audio file: \(error), using synthetic")
            audioBuffer = generateSyntheticClick()
        }
    }

    private func generateSyntheticClick() -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let duration: Double = 0.05  // 50ms click
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        // Generate a short click/tick sound
        let frequency: Float = 1000  // 1kHz
        let attackSamples = Int(sampleRate * 0.005)  // 5ms attack
        let decaySamples = Int(frameCount) - attackSamples

        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            var sample = sin(2.0 * .pi * frequency * t)

            // Apply envelope
            if i < attackSamples {
                sample *= Float(i) / Float(attackSamples)
            } else {
                let decayProgress = Float(i - attackSamples) / Float(decaySamples)
                sample *= 1.0 - decayProgress
            }

            channelData[i] = sample * 0.8
        }

        return buffer
    }

    // MARK: - Metronome Timer
    private func startMetronomeTimer() {
        let interval = 60.0 / Double(currentBPM)

        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playClick()
        }

        // Fire immediately for first beat
        playClick()
    }

    private func stopMetronomeTimer() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }

    private func playClick() {
        guard let player = playerNode, let buffer = audioBuffer else { return }

        player.volume = currentVolume
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        if !player.isPlaying {
            player.play()
        }
    }

    // MARK: - Voice Announcements
    func announce(_ message: String) async {
        guard isVoiceEnabled else { return }

        await MainActor.run {
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: currentLanguage)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1  // Slightly faster
            utterance.volume = voiceVolume
            utterance.pitchMultiplier = 1.0

            speechSynthesizer?.speak(utterance)

            Log.audio.debug("Announcing: '\(message)'")
        }
    }

    func announcePhaseChange(_ phase: IntervalPhase) async {
        let message = phase.startAnnouncement
        guard !message.isEmpty else { return }
        await announce(message)
    }

    func announceTimeWarning(secondsRemaining: Int) async {
        let message: String
        switch secondsRemaining {
        case 30:
            message = "Treinta segundos"
        case 10:
            message = "Diez segundos"
        case 5:
            message = "Cinco"
        case 3:
            message = "Tres"
        case 2:
            message = "Dos"
        case 1:
            message = "Uno"
        default:
            message = "\(secondsRemaining) segundos"
        }

        await announce(message)
    }

    func announceZoneStatus(_ status: ZoneStatus) async {
        await announce(status.instruction)
    }

    func announceCoachingInstruction(_ instruction: CoachingInstruction) async {
        await announce(instruction.voiceMessage)
    }

    func stopVoice() {
        speechSynthesizer?.stopSpeaking(at: .immediate)
    }

    private var currentLanguage: String {
        // Use device language, defaulting to Spanish
        let preferred = Locale.preferredLanguages.first ?? "es-ES"
        return preferred.hasPrefix("en") ? "en-US" : "es-ES"
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension MetronomeEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // Music is automatically ducked due to .duckOthers option
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Music volume restored automatically
    }
}

// MARK: - Metronome Preview Helper
extension MetronomeEngine {
    /// Preview a sound without starting the full metronome
    func previewSound(_ soundType: MetronomeSoundType) {
        Task {
            do {
                try loadAudioBuffer(for: soundType)
                setupAudioEngine()
                playClick()

                // Stop after preview
                try await Task.sleep(for: .milliseconds(500))
                audioEngine?.stop()
                playerNode?.stop()
            } catch {
                Log.audio.error("Preview failed: \(error)")
            }
        }
    }
}
