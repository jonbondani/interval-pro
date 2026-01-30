import Foundation
import Combine
import MusicKit
import MediaPlayer
import os

/// Apple Music controller using MusicKit
/// Provides playback control for Apple Music subscribers
@MainActor
final class AppleMusicController: MusicControllerProtocol {

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
    let serviceType: MusicServiceType = .appleMusic
    private(set) var currentVolume: Float = 0.7

    private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    private lazy var systemPlayer: MPMusicPlayerController = {
        MPMusicPlayerController.systemMusicPlayer
    }()
    private var hasSetupObservers = false
    private var cancellables = Set<AnyCancellable>()
    private var playbackObserver: NSObjectProtocol?
    private var nowPlayingObserver: NSObjectProtocol?

    private let logger = Logger(subsystem: "com.intervalpro.app", category: "AppleMusic")

    // MARK: - Singleton

    static let shared = AppleMusicController()

    // MARK: - Init

    private init() {
        // Don't access system player until authorized
        // This prevents crash when NSAppleMusicUsageDescription is accessed
        checkAuthorizationStatus()
    }

    deinit {
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = nowPlayingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        guard !hasSetupObservers else { return }
        hasSetupObservers = true

        // Observe playback state changes
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlaybackState()
        }

        // Observe now playing changes
        nowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemPlayer,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }

        // Begin generating notifications
        systemPlayer.beginGeneratingPlaybackNotifications()

        // Initial state update
        updatePlaybackState()
        updateNowPlaying()
    }

    private func checkAuthorizationStatus() {
        Task { @MainActor in
            authorizationStatus = MusicAuthorization.currentStatus
            isConnected = authorizationStatus == .authorized

            // Only setup observers if already authorized
            if isConnected && !hasSetupObservers {
                setupObservers()
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        logger.info("Requesting MusicKit authorization")

        // Try MusicKit authorization, but don't fail completely if it doesn't work
        // We can still use MPMusicPlayerController for basic control
        do {
            let status = await MusicAuthorization.request()
            authorizationStatus = status

            switch status {
            case .authorized:
                isConnected = true
                logger.info("MusicKit authorization granted")
                setupObservers()
                return

            case .denied:
                logger.warning("MusicKit authorization denied - falling back to basic control")

            case .restricted:
                logger.warning("MusicKit access restricted - falling back to basic control")

            case .notDetermined:
                logger.warning("MusicKit authorization not determined - falling back to basic control")

            @unknown default:
                logger.warning("Unknown MusicKit status - falling back to basic control")
            }
        } catch {
            logger.warning("MusicKit authorization failed: \(error) - falling back to basic control")
        }

        // Even without full MusicKit authorization, we can use system player for basic control
        // This allows play/pause/skip to work with whatever music app is active
        isConnected = true
        setupObservers()
        logger.info("Apple Music controller ready (basic mode)")
    }

    // MARK: - Playback Control

    func play() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Playing Apple Music")
        systemPlayer.play()
    }

    func pause() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Pausing Apple Music")
        systemPlayer.pause()
    }

    func skipToNext() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Skipping to next track")
        systemPlayer.skipToNextItem()
    }

    func skipToPrevious() async throws {
        guard isConnected else {
            throw MusicError.notConnected
        }

        logger.debug("Skipping to previous track")
        systemPlayer.skipToPreviousItem()
    }

    func setVolume(_ volume: Float) async {
        currentVolume = max(0, min(1, volume))

        // Note: MPMusicPlayerController doesn't have direct volume control
        // We use MPVolumeView's slider or system volume
        // This is a limitation of the API
        logger.debug("Volume set to \(volume) (system controlled)")
    }

    // MARK: - State Updates

    private func updatePlaybackState() {
        guard hasSetupObservers else { return }

        let newState: MusicPlaybackState

        switch systemPlayer.playbackState {
        case .playing:
            newState = .playing
        case .paused:
            newState = .paused
        case .stopped:
            newState = .stopped
        case .interrupted:
            newState = .interrupted
        case .seekingForward, .seekingBackward:
            newState = .playing
        @unknown default:
            newState = .unknown
        }

        playbackStateSubject.send(newState)
        logger.debug("Playback state: \(String(describing: newState))")
    }

    private func updateNowPlaying() {
        guard hasSetupObservers else { return }

        guard let item = systemPlayer.nowPlayingItem else {
            nowPlayingSubject.send(nil)
            return
        }

        let artworkData = item.artwork?.image(at: CGSize(width: 300, height: 300))
            .flatMap { UIImagePNGRepresentation($0) }

        let track = MusicTrack(
            id: item.persistentID.description,
            title: item.title ?? "Unknown",
            artist: item.artist ?? "Unknown Artist",
            album: item.albumTitle,
            duration: item.playbackDuration,
            artworkURL: nil,
            artworkData: artworkData
        )

        nowPlayingSubject.send(track)
        logger.debug("Now playing: \(track.title) - \(track.artist)")
    }
}

// MARK: - UIImage Extension

#if canImport(UIKit)
import UIKit

private func UIImagePNGRepresentation(_ image: UIImage) -> Data? {
    image.pngData()
}
#endif
