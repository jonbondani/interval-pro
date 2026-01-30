import Foundation
import MediaPlayer
import Combine
import UIKit
import os

/// Spotify controller for playback control
/// Uses MPRemoteCommandCenter to control the currently playing app (including Spotify)
/// and MPNowPlayingInfoCenter to get playback info
@MainActor
final class SpotifyController: MusicControllerProtocol {

    // MARK: - Published State

    private let playbackStateSubject = CurrentValueSubject<MusicPlaybackState, Never>(.stopped)
    private let nowPlayingSubject = CurrentValueSubject<MusicTrack?, Never>(nil)

    var playbackState: AnyPublisher<MusicPlaybackState, Never> {
        playbackStateSubject.eraseToAnyPublisher()
    }

    var nowPlaying: AnyPublisher<MusicTrack?, Never> {
        nowPlayingSubject.eraseToAnyPublisher()
    }

    // MARK: - Properties

    private(set) var isConnected: Bool = false
    let serviceType: MusicServiceType = .spotify
    private(set) var currentVolume: Float = 0.7

    private var hasSetupObservers = false
    private var updateTimer: Timer?

    private let logger = Logger(subsystem: "com.intervalpro.app", category: "Spotify")

    // MARK: - Singleton

    static let shared = SpotifyController()

    // MARK: - Init

    private init() {
        checkSpotifyAvailability()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Setup

    private func checkSpotifyAvailability() {
        isConnected = isSpotifyInstalled
        if isConnected {
            logger.info("Spotify app is installed")
        }
    }

    private var isSpotifyInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func setupObservers() {
        guard !hasSetupObservers else { return }
        hasSetupObservers = true

        // Use a timer to periodically check MPNowPlayingInfoCenter
        // This is more reliable for external apps like Spotify
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromNowPlayingInfoCenter()
            }
        }

        // Also observe the notification for immediate updates
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromNowPlayingInfoCenter()
            }
        }

        // Initial update
        updateFromNowPlayingInfoCenter()

        logger.debug("Spotify observers set up")
    }

    /// Update state from MPNowPlayingInfoCenter
    private func updateFromNowPlayingInfoCenter() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo

        // Update playback state
        let newState: MusicPlaybackState
        if let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double, rate > 0 {
            newState = .playing
        } else if info != nil {
            newState = .paused
        } else {
            newState = .stopped
        }

        if playbackStateSubject.value != newState {
            playbackStateSubject.send(newState)
            logger.debug("Playback state updated: \(String(describing: newState))")
        }

        // Update now playing track
        if let title = info?[MPMediaItemPropertyTitle] as? String {
            let artist = info?[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
            let album = info?[MPMediaItemPropertyAlbumTitle] as? String
            let duration = info?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval ?? 0

            var artworkData: Data?
            if let artwork = info?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                artworkData = artwork.image(at: CGSize(width: 300, height: 300))?.pngData()
            }

            let track = MusicTrack(
                id: "\(title)-\(artist)",
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                artworkURL: nil,
                artworkData: artworkData
            )

            // Only update if track changed
            if nowPlayingSubject.value?.id != track.id {
                nowPlayingSubject.send(track)
                logger.debug("Now playing: \(track.title) - \(track.artist)")
            }
        } else if nowPlayingSubject.value != nil {
            nowPlayingSubject.send(nil)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        logger.info("Checking Spotify availability")

        guard isSpotifyInstalled else {
            logger.warning("Spotify app not installed")
            throw MusicError.spotifyNotInstalled
        }

        isConnected = true
        setupObservers()

        // Force an immediate update
        updateFromNowPlayingInfoCenter()

        logger.info("Spotify controller ready")
    }

    // MARK: - Playback Control using URL schemes

    func play() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Sending play command to Spotify")

        // Open Spotify with play intent
        if let url = URL(string: "spotify:play") {
            await UIApplication.shared.open(url)
        } else {
            // Fallback: just open Spotify
            openSpotifyApp()
        }

        // Wait a moment and update state
        try? await Task.sleep(for: .milliseconds(500))
        updateFromNowPlayingInfoCenter()
    }

    func pause() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Sending pause command to Spotify")

        // Open Spotify with pause intent
        if let url = URL(string: "spotify:pause") {
            await UIApplication.shared.open(url)
        }

        // Wait a moment and update state
        try? await Task.sleep(for: .milliseconds(500))
        updateFromNowPlayingInfoCenter()
    }

    func skipToNext() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Sending skip next command to Spotify")

        // Open Spotify with next intent
        if let url = URL(string: "spotify:next") {
            await UIApplication.shared.open(url)
        }

        try? await Task.sleep(for: .milliseconds(500))
        updateFromNowPlayingInfoCenter()
    }

    func skipToPrevious() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Sending skip previous command to Spotify")

        // Open Spotify with previous intent
        if let url = URL(string: "spotify:previous") {
            await UIApplication.shared.open(url)
        }

        try? await Task.sleep(for: .milliseconds(500))
        updateFromNowPlayingInfoCenter()
    }

    func setVolume(_ volume: Float) async {
        currentVolume = max(0, min(1, volume))
        logger.debug("Volume set to \(volume) (system controlled)")
    }

    // MARK: - Spotify Deep Link

    func openSpotifyApp() {
        if let url = URL(string: "spotify://") {
            UIApplication.shared.open(url)
        }
    }

    /// Force refresh the current state
    func refreshState() {
        updateFromNowPlayingInfoCenter()
    }

    // Legacy method for URL callback (not needed)
    func handleAuthCallback(url: URL) {
        logger.debug("Auth callback received but not needed")
    }
}
