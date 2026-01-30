import Foundation
import Combine
import MediaPlayer
import UIKit
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

        // Immediately set Spotify as active if installed (before bindings)
        // This ensures Spotify is the default service
        if isSpotifyInstalled {
            self.activeService = .spotify
            self.activeController = spotifyController
            self.isConnected = true
        }

        setupBindings()

        Task {
            await detectActiveService()
        }
    }

    /// Check if Spotify app is installed
    private var isSpotifyInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
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
        // Since both controllers use the same MPMusicPlayerController.systemMusicPlayer,
        // they receive the same events. We only forward from Spotify when it's active
        // (Spotify is the preferred/default service)

        // Subscribe to Spotify state - this is the primary source
        spotifyController.playbackState
            .sink { [weak self] state in
                guard let self = self else { return }
                // Forward Spotify state when Spotify is active
                if self.activeService == .spotify {
                    self.playbackState = state
                }
            }
            .store(in: &cancellables)

        spotifyController.nowPlaying
            .sink { [weak self] track in
                guard let self = self else { return }
                if self.activeService == .spotify {
                    self.nowPlaying = track
                }
            }
            .store(in: &cancellables)

        // Subscribe to Apple Music state - only used if Spotify is not available
        appleMusicController.playbackState
            .sink { [weak self] state in
                guard let self = self else { return }
                // Only forward Apple Music state when Apple Music is active
                if self.activeService == .appleMusic {
                    self.playbackState = state
                }
            }
            .store(in: &cancellables)

        appleMusicController.nowPlaying
            .sink { [weak self] track in
                guard let self = self else { return }
                if self.activeService == .appleMusic {
                    self.nowPlaying = track
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Service Detection

    /// Detect and activate the appropriate music service
    /// Prioritizes Spotify when installed (avoids MusicKit entitlement issues)
    func detectActiveService() async {
        logger.debug("Detecting active music service...")

        // Always try Spotify first if installed (avoids MusicKit authorization issues)
        if await tryActivateSpotify() {
            return
        }

        // Fall back to Apple Music
        if await tryActivateAppleMusic() {
            return
        }

        // No service available
        activeService = .none
        activeController = nil
        isConnected = false

        logger.info("No music service available")
    }

    /// Check which service is currently playing and activate it
    private func checkAndActivatePlayingService() async -> Bool {
        // Always initialize Spotify first (no authorization dialog needed)
        try? await spotifyController.requestAuthorization()

        // Check if any music is currently playing
        let isAnythingPlaying = isSystemMusicPlaying()

        if isAnythingPlaying && spotifyController.isConnected {
            // If Spotify is installed and music is playing, use Spotify
            activateService(.spotify, controller: spotifyController)
            logger.info("Music playing, Spotify installed - activating Spotify")
            return true
        }

        // Only try Apple Music if Spotify is not available
        if !spotifyController.isConnected {
            try? await appleMusicController.requestAuthorization()

            if isAnythingPlaying && appleMusicController.isConnected {
                activateService(.appleMusic, controller: appleMusicController)
                logger.info("Music playing - activating Apple Music")
                return true
            }
        }

        return false
    }

    /// Check if system music player is currently playing
    private func isSystemMusicPlaying() -> Bool {
        // Check MPNowPlayingInfoCenter for playback rate
        if let rate = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double,
           rate > 0 {
            return true
        }
        return false
    }

    /// Try to detect which service is playing from now playing info
    private func detectActiveServiceFromNowPlaying() -> MusicServiceType {
        guard let info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return .none
        }

        // Check if there's a bundle identifier or app name hint
        // Some apps put their name in the album artist or other fields
        let allValues = info.values.compactMap { $0 as? String }.joined(separator: " ").lowercased()

        if allValues.contains("spotify") {
            return .spotify
        }

        // If the track is from Apple Music library, it might have a persistent ID
        if info[MPMediaItemPropertyPersistentID] != nil {
            return .appleMusic
        }

        return .none
    }

    /// Check if Apple Music is currently playing
    private func isAppleMusicPlaying() async -> Bool {
        return isSystemMusicPlaying() && detectActiveServiceFromNowPlaying() != .spotify
    }

    /// Check if Spotify is currently playing
    private func isSpotifyPlaying() async -> Bool {
        return isSystemMusicPlaying() && (detectActiveServiceFromNowPlaying() == .spotify || spotifyController.isConnected)
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

        // Also sync the current state from the controller
        syncStateFromController(controller, type: type)

        logger.info("Activated music service: \(type.displayName)")
    }

    /// Sync playback state and now playing from the active controller
    private func syncStateFromController(_ controller: MusicControllerProtocol, type: MusicServiceType) {
        // Subscribe to get current values
        controller.playbackState
            .first()
            .sink { [weak self] state in
                self?.playbackState = state
            }
            .store(in: &cancellables)

        controller.nowPlaying
            .first()
            .sink { [weak self] track in
                self?.nowPlaying = track
            }
            .store(in: &cancellables)
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
        // Auto-detect service if not connected
        if activeController == nil {
            await detectActiveService()
        }

        guard let controller = activeController else {
            error = .notConnected
            return
        }

        do {
            try await controller.play()
            error = nil
            // Give the player a moment to update, then refresh state
            try? await Task.sleep(for: .milliseconds(200))
            await refreshPlaybackState()
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
            // Give the player a moment to update, then refresh state
            try? await Task.sleep(for: .milliseconds(200))
            await refreshPlaybackState()
        } catch let musicError as MusicError {
            error = musicError
            logger.error("Pause failed: \(musicError.localizedDescription)")
        } catch {
            self.error = .playbackFailed(underlying: error)
            logger.error("Pause failed: \(error.localizedDescription)")
        }
    }

    func togglePlayPause() async {
        // Auto-detect service if not connected
        if activeController == nil {
            await detectActiveService()
        }

        if playbackState.isPlaying {
            await pause()
        } else {
            await play()
        }
    }

    /// Manually refresh the playback state from the active controller
    /// Also checks if a different service started playing
    func refreshPlaybackState() async {
        // First check if a different service is now playing
        let isSpotifyCurrentlyPlaying = await isSpotifyPlaying()
        let isAppleMusicCurrentlyPlaying = await isAppleMusicPlaying()

        let spotifyPlaying = spotifyController.isConnected && isSpotifyCurrentlyPlaying
        let appleMusicPlaying = appleMusicController.isConnected && isAppleMusicCurrentlyPlaying

        // Switch to the playing service if different from current
        if spotifyPlaying && activeService != .spotify {
            activateService(.spotify, controller: spotifyController)
            logger.info("Switched to Spotify (now playing)")
        } else if appleMusicPlaying && activeService != .appleMusic && !spotifyPlaying {
            activateService(.appleMusic, controller: appleMusicController)
            logger.info("Switched to Apple Music (now playing)")
        }

        // Sync state from active controller
        if let controller = activeController {
            syncStateFromController(controller, type: activeService)
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

        logger.debug("Music restored to \(self.config.musicVolume)")
    }

    // MARK: - Config Persistence

    private static func loadConfig() -> MusicControllerConfig {
        // Always use default config with Spotify preference
        // This ensures Spotify is preferred over Apple Music
        // Clear any old saved config
        UserDefaults.standard.removeObject(forKey: "music_controller_config")
        return .default
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
