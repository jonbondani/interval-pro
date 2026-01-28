import Foundation
import Combine
import os

/// Unified music controller that manages both Apple Music and Spotify
/// Auto-detects active player and provides seamless switching
@MainActor
final class UnifiedMusicController: ObservableObject {

    // MARK: - Published State

    @Published private(set) var activeService: MusicServiceType = .none
    @Published private(set) var playbackState: MusicPlaybackState = .stopped
    @Published private(set) var nowPlaying: MusicTrack?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var error: MusicError?

    @Published var config: MusicControllerConfig {
        didSet {
            saveConfig()
            if config.preferredService != oldValue.preferredService {
                Task { await switchToPreferredService() }
            }
        }
    }

    // MARK: - Properties

    var currentVolume: Float {
        activeController?.currentVolume ?? config.musicVolume
    }

    private var activeController: MusicControllerProtocol?
    private let appleMusicController: AppleMusicController
    private let spotifyController: SpotifyController

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.intervalpro.app", category: "UnifiedMusic")

    private let configKey = "music_controller_config"

    // MARK: - Singleton

    static let shared = UnifiedMusicController()

    // MARK: - Init

    private init(
        appleMusicController: AppleMusicController = .shared,
        spotifyController: SpotifyController = .shared
    ) {
        self.appleMusicController = appleMusicController
        self.spotifyController = spotifyController
        self.config = Self.loadConfig()

        setupBindings()

        Task {
            await detectActiveService()
        }
    }

    // For testing
    init(
        appleMusicController: AppleMusicController,
        spotifyController: SpotifyController,
        config: MusicControllerConfig = .default
    ) {
        self.appleMusicController = appleMusicController
        self.spotifyController = spotifyController
        self.config = config

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to Apple Music state
        appleMusicController.playbackState
            .sink { [weak self] state in
                if self?.activeService == .appleMusic {
                    self?.playbackState = state
                }
            }
            .store(in: &cancellables)

        appleMusicController.nowPlaying
            .sink { [weak self] track in
                if self?.activeService == .appleMusic {
                    self?.nowPlaying = track
                }
            }
            .store(in: &cancellables)

        // Subscribe to Spotify state
        spotifyController.playbackState
            .sink { [weak self] state in
                if self?.activeService == .spotify {
                    self?.playbackState = state
                }
            }
            .store(in: &cancellables)

        spotifyController.nowPlaying
            .sink { [weak self] track in
                if self?.activeService == .spotify {
                    self?.nowPlaying = track
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Service Detection

    /// Detect and activate the appropriate music service
    func detectActiveService() async {
        logger.debug("Detecting active music service...")

        // Try preferred service first
        switch config.preferredService {
        case .appleMusic:
            if await tryActivateAppleMusic() { return }
            if await tryActivateSpotify() { return }

        case .spotify:
            if await tryActivateSpotify() { return }
            if await tryActivateAppleMusic() { return }

        case .none:
            // Auto-detect: check which one is playing
            if await tryActivateAppleMusic() { return }
            if await tryActivateSpotify() { return }
        }

        // No service available
        activeService = .none
        activeController = nil
        isConnected = false

        logger.info("No music service available")
    }

    private func tryActivateAppleMusic() async -> Bool {
        do {
            try await appleMusicController.requestAuthorization()
            if appleMusicController.isConnected {
                activateService(.appleMusic, controller: appleMusicController)
                return true
            }
        } catch {
            logger.debug("Apple Music not available: \(error.localizedDescription)")
        }
        return false
    }

    private func tryActivateSpotify() async -> Bool {
        do {
            try await spotifyController.requestAuthorization()
            if spotifyController.isConnected {
                activateService(.spotify, controller: spotifyController)
                return true
            }
        } catch {
            logger.debug("Spotify not available: \(error.localizedDescription)")
        }
        return false
    }

    private func activateService(_ type: MusicServiceType, controller: MusicControllerProtocol) {
        activeService = type
        activeController = controller
        isConnected = controller.isConnected

        logger.info("Activated music service: \(type.displayName)")
    }

    private func switchToPreferredService() async {
        guard config.preferredService != .none else {
            activeService = .none
            activeController = nil
            isConnected = false
            return
        }

        await detectActiveService()
    }

    // MARK: - Playback Control

    func play() async {
        guard let controller = activeController else {
            error = .notConnected
            return
        }

        do {
            try await controller.play()
            error = nil
        } catch let musicError as MusicError {
            error = musicError
            logger.error("Play failed: \(musicError.localizedDescription)")
        } catch {
            self.error = .playbackFailed(underlying: error)
            logger.error("Play failed: \(error.localizedDescription)")
        }
    }

    func pause() async {
        guard let controller = activeController else {
            error = .notConnected
            return
        }

        do {
            try await controller.pause()
            error = nil
        } catch let musicError as MusicError {
            error = musicError
            logger.error("Pause failed: \(musicError.localizedDescription)")
        } catch {
            self.error = .playbackFailed(underlying: error)
            logger.error("Pause failed: \(error.localizedDescription)")
        }
    }

    func togglePlayPause() async {
        if playbackState.isPlaying {
            await pause()
        } else {
            await play()
        }
    }

    func skipToNext() async {
        guard let controller = activeController else {
            error = .notConnected
            return
        }

        do {
            try await controller.skipToNext()
            error = nil
        } catch {
            self.error = .playbackFailed(underlying: error)
            logger.error("Skip next failed: \(error.localizedDescription)")
        }
    }

    func skipToPrevious() async {
        guard let controller = activeController else {
            error = .notConnected
            return
        }

        do {
            try await controller.skipToPrevious()
            error = nil
        } catch {
            self.error = .playbackFailed(underlying: error)
            logger.error("Skip previous failed: \(error.localizedDescription)")
        }
    }

    func setVolume(_ volume: Float) async {
        config.musicVolume = max(0, min(1, volume))
        await activeController?.setVolume(volume)
    }

    // MARK: - Audio Ducking

    /// Reduce music volume for voice announcements
    func duckForAnnouncement() async {
        guard config.duckDuringAnnouncements else { return }

        let duckedVolume = config.musicVolume * config.duckingLevel
        await activeController?.setVolume(duckedVolume)

        logger.debug("Music ducked to \(duckedVolume)")
    }

    /// Restore music volume after announcement
    func restoreFromDuck() async {
        guard config.duckDuringAnnouncements else { return }

        await activeController?.setVolume(config.musicVolume)

        logger.debug("Music restored to \(config.musicVolume)")
    }

    // MARK: - Config Persistence

    private static func loadConfig() -> MusicControllerConfig {
        guard let data = UserDefaults.standard.data(forKey: "music_controller_config"),
              let config = try? JSONDecoder().decode(MusicControllerConfig.self, from: data) else {
            return .default
        }
        return config
    }

    private func saveConfig() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: configKey)
    }

    // MARK: - Authorization

    func authorizeAppleMusic() async throws {
        try await appleMusicController.requestAuthorization()
        if appleMusicController.isConnected {
            config.preferredService = .appleMusic
            activateService(.appleMusic, controller: appleMusicController)
        }
    }

    func authorizeSpotify() async throws {
        try await spotifyController.requestAuthorization()
        if spotifyController.isConnected {
            config.preferredService = .spotify
            activateService(.spotify, controller: spotifyController)
        }
    }

    /// Handle Spotify OAuth callback
    func handleSpotifyCallback(url: URL) {
        spotifyController.handleAuthCallback(url: url)

        Task {
            try? await Task.sleep(for: .seconds(1))
            if spotifyController.isConnected {
                config.preferredService = .spotify
                activateService(.spotify, controller: spotifyController)
            }
        }
    }
}
