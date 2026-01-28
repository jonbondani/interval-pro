import Foundation
import UIKit
import Combine
import os

/// Spotify controller for playback control
/// Uses Spotify iOS SDK for Premium users
/// Note: Requires Spotify app to be installed
@MainActor
final class SpotifyController: @preconcurrency MusicControllerProtocol {

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

    // Spotify configuration
    private let clientID: String
    private let redirectURI: URL
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?

    // Remote control
    private var appRemote: SpotifyAppRemote?
    private var connectionRetryCount = 0
    private let maxConnectionRetries = 3

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.intervalpro.app", category: "Spotify")

    // Keychain keys
    private let accessTokenKey = "spotify_access_token"
    private let refreshTokenKey = "spotify_refresh_token"
    private let tokenExpirationKey = "spotify_token_expiration"

    // MARK: - Singleton

    static let shared = SpotifyController()

    // MARK: - Init

    private init() {
        // Load configuration from environment or config file
        self.clientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"] ?? ""
        self.redirectURI = URL(string: ProcessInfo.processInfo.environment["SPOTIFY_REDIRECT_URI"] ?? "intervalpro://spotify-callback")!

        loadStoredTokens()
        setupAppRemote()
    }

    // MARK: - Setup

    private func setupAppRemote() {
        guard !clientID.isEmpty else {
            logger.warning("Spotify client ID not configured")
            return
        }

        let configuration = SpotifyConfiguration(
            clientID: clientID,
            redirectURI: redirectURI
        )

        appRemote = SpotifyAppRemote(configuration: configuration)
        appRemote?.delegate = self

        // If we have a stored token, try to connect
        if let token = accessToken, !isTokenExpired {
            appRemote?.connectionParameters.accessToken = token
        }
    }

    private var isTokenExpired: Bool {
        guard let expiration = tokenExpirationDate else { return true }
        return Date() > expiration
    }

    // MARK: - Token Management

    private func loadStoredTokens() {
        // Load from Keychain
        accessToken = KeychainManager.load(key: accessTokenKey)
        refreshToken = KeychainManager.load(key: refreshTokenKey)

        if let expirationString = KeychainManager.load(key: tokenExpirationKey),
           let timestamp = TimeInterval(expirationString) {
            tokenExpirationDate = Date(timeIntervalSince1970: timestamp)
        }

        logger.debug("Loaded stored Spotify tokens: \(self.accessToken != nil)")
    }

    private func storeTokens(access: String, refresh: String?, expiration: Date) {
        accessToken = access
        refreshToken = refresh
        tokenExpirationDate = expiration

        KeychainManager.save(key: accessTokenKey, value: access)
        if let refresh = refresh {
            KeychainManager.save(key: refreshTokenKey, value: refresh)
        }
        KeychainManager.save(key: tokenExpirationKey, value: String(expiration.timeIntervalSince1970))

        logger.debug("Stored Spotify tokens")
    }

    private func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpirationDate = nil

        KeychainManager.delete(key: accessTokenKey)
        KeychainManager.delete(key: refreshTokenKey)
        KeychainManager.delete(key: tokenExpirationKey)

        logger.debug("Cleared Spotify tokens")
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        logger.info("Requesting Spotify authorization")

        guard isSpotifyInstalled else {
            logger.warning("Spotify app not installed")
            throw MusicError.spotifyNotInstalled
        }

        // If we have a valid token, just connect
        if let token = accessToken, !isTokenExpired {
            appRemote?.connectionParameters.accessToken = token
            try await connect()
            return
        }

        // Need to trigger OAuth flow
        // This would typically open Spotify app for authorization
        // The result comes back via URL scheme handling

        let authorizeURL = buildAuthorizationURL()

        await MainActor.run {
            UIApplication.shared.open(authorizeURL, options: [:]) { [weak self] success in
                if !success {
                    self?.logger.error("Failed to open Spotify authorization URL")
                }
            }
        }

        // Note: The actual token will be received via URL scheme callback
        // This is handled in SceneDelegate/AppDelegate
    }

    private var isSpotifyInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func buildAuthorizationURL() -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: "app-remote-control user-read-playback-state user-modify-playback-state"),
            URLQueryItem(name: "show_dialog", value: "false")
        ]
        return components.url!
    }

    /// Handle OAuth callback URL
    func handleAuthCallback(url: URL) {
        logger.info("Handling Spotify auth callback")

        // Parse token from URL fragment
        guard let fragment = url.fragment else {
            logger.error("No fragment in callback URL")
            return
        }

        let params = parseURLFragment(fragment)

        guard let token = params["access_token"] else {
            logger.error("No access token in callback")
            return
        }

        let expiresIn = TimeInterval(params["expires_in"] ?? "3600") ?? 3600
        let expiration = Date().addingTimeInterval(expiresIn)

        storeTokens(access: token, refresh: nil, expiration: expiration)

        // Connect with new token
        appRemote?.connectionParameters.accessToken = token
        Task {
            try? await connect()
        }
    }

    private func parseURLFragment(_ fragment: String) -> [String: String] {
        var params: [String: String] = [:]
        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                params[kv[0]] = kv[1].removingPercentEncoding
            }
        }
        return params
    }

    // MARK: - Connection

    private func connect() async throws {
        guard let appRemote = appRemote else {
            throw MusicError.serviceUnavailable
        }

        guard isSpotifyInstalled else {
            throw MusicError.spotifyNotInstalled
        }

        logger.debug("Connecting to Spotify...")

        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            appRemote.connect()
        }
    }

    private var connectionContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Playback Control

    func play() async throws {
        guard isConnected, let playerAPI = appRemote?.playerAPI else {
            throw MusicError.notConnected
        }

        logger.debug("Playing Spotify")

        return try await withCheckedThrowingContinuation { continuation in
            playerAPI.resume { _, error in
                if let error = error {
                    continuation.resume(throwing: MusicError.playbackFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func pause() async throws {
        guard isConnected, let playerAPI = appRemote?.playerAPI else {
            throw MusicError.notConnected
        }

        logger.debug("Pausing Spotify")

        return try await withCheckedThrowingContinuation { continuation in
            playerAPI.pause { _, error in
                if let error = error {
                    continuation.resume(throwing: MusicError.playbackFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func skipToNext() async throws {
        guard isConnected, let playerAPI = appRemote?.playerAPI else {
            throw MusicError.notConnected
        }

        logger.debug("Skipping to next Spotify track")

        return try await withCheckedThrowingContinuation { continuation in
            playerAPI.skip(toNext: { _, error in
                if let error = error {
                    continuation.resume(throwing: MusicError.playbackFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func skipToPrevious() async throws {
        guard isConnected, let playerAPI = appRemote?.playerAPI else {
            throw MusicError.notConnected
        }

        logger.debug("Skipping to previous Spotify track")

        return try await withCheckedThrowingContinuation { continuation in
            playerAPI.skip(toPrevious: { _, error in
                if let error = error {
                    continuation.resume(throwing: MusicError.playbackFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func setVolume(_ volume: Float) async {
        currentVolume = max(0, min(1, volume))
        // Spotify doesn't support direct volume control from SDK
        // Volume is controlled through system
        logger.debug("Volume set to \(volume) (system controlled)")
    }

    // MARK: - Disconnect

    func disconnect() {
        appRemote?.disconnect()
        isConnected = false
        playbackStateSubject.send(.stopped)
        nowPlayingSubject.send(nil)
        logger.info("Disconnected from Spotify")
    }
}

// MARK: - SpotifyAppRemoteDelegate

extension SpotifyController: SpotifyAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SpotifyAppRemote) {
        Task { @MainActor in
            logger.info("Spotify connection established")
            isConnected = true
            connectionRetryCount = 0

            // Subscribe to player state
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] result, error in
                if let error = error {
                    self?.logger.error("Failed to subscribe to player state: \(error)")
                }
            })

            connectionContinuation?.resume()
            connectionContinuation = nil
        }
    }

    nonisolated func appRemote(_ appRemote: SpotifyAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            logger.error("Spotify connection failed: \(error?.localizedDescription ?? "unknown")")
            isConnected = false

            // Retry logic
            if connectionRetryCount < maxConnectionRetries {
                connectionRetryCount += 1
                logger.debug("Retrying connection (\(self.connectionRetryCount)/\(self.maxConnectionRetries))")
                try? await Task.sleep(for: .seconds(2))
                try? await connect()
            } else {
                connectionContinuation?.resume(throwing: error ?? MusicError.serviceUnavailable)
                connectionContinuation = nil
            }
        }
    }

    nonisolated func appRemote(_ appRemote: SpotifyAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            logger.warning("Spotify disconnected: \(error?.localizedDescription ?? "no error")")
            isConnected = false
            playbackStateSubject.send(.stopped)
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate

extension SpotifyController: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            // Update playback state
            let newState: MusicPlaybackState = playerState.isPaused ? .paused : .playing
            playbackStateSubject.send(newState)

            // Update now playing
            let track = MusicTrack(
                id: playerState.track.uri,
                title: playerState.track.name,
                artist: playerState.track.artist.name,
                album: playerState.track.album.name,
                duration: TimeInterval(playerState.track.duration) / 1000,
                artworkURL: nil,
                artworkData: nil
            )
            nowPlayingSubject.send(track)

            logger.debug("Spotify state: \(String(describing: newState)), track: \(track.title)")
        }
    }
}

// MARK: - Spotify Types (Placeholder)

// These would come from the Spotify SDK
// Defined here as placeholders for compilation

protocol SpotifyAppRemoteDelegate: AnyObject {
    func appRemoteDidEstablishConnection(_ appRemote: SpotifyAppRemote)
    func appRemote(_ appRemote: SpotifyAppRemote, didFailConnectionAttemptWithError error: Error?)
    func appRemote(_ appRemote: SpotifyAppRemote, didDisconnectWithError error: Error?)
}

protocol SPTAppRemotePlayerStateDelegate: AnyObject {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState)
}

struct SpotifyConfiguration {
    let clientID: String
    let redirectURI: URL
}

class SpotifyAppRemote {
    weak var delegate: SpotifyAppRemoteDelegate?
    var playerAPI: SpotifyPlayerAPI?
    var connectionParameters: SpotifyConnectionParameters

    init(configuration: SpotifyConfiguration) {
        self.connectionParameters = SpotifyConnectionParameters()
    }

    func connect() {}
    func disconnect() {}
}

class SpotifyConnectionParameters {
    var accessToken: String?
}

class SpotifyPlayerAPI {
    weak var delegate: SPTAppRemotePlayerStateDelegate?

    func subscribe(toPlayerState callback: @escaping (Any?, Error?) -> Void) {}
    func resume(_ callback: @escaping (Any?, Error?) -> Void) {}
    func pause(_ callback: @escaping (Any?, Error?) -> Void) {}
    func skip(toNext callback: @escaping (Any?, Error?) -> Void) {}
    func skip(toPrevious callback: @escaping (Any?, Error?) -> Void) {}
}

protocol SPTAppRemotePlayerState {
    var isPaused: Bool { get }
    var track: SPTAppRemoteTrack { get }
}

protocol SPTAppRemoteTrack {
    var uri: String { get }
    var name: String { get }
    var duration: Int { get }
    var artist: SPTAppRemoteArtist { get }
    var album: SPTAppRemoteAlbum { get }
}

protocol SPTAppRemoteArtist {
    var name: String { get }
}

protocol SPTAppRemoteAlbum {
    var name: String { get }
}

// MARK: - Keychain Manager

private enum KeychainManager {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
