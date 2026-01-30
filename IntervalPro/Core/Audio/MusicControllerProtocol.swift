import Foundation
import Combine

/// Unified protocol for music playback control
/// Abstracts Apple Music and Spotify implementations
protocol MusicControllerProtocol: AnyObject {
    /// Current playback state
    var playbackState: AnyPublisher<MusicPlaybackState, Never> { get }

    /// Currently playing track info
    var nowPlaying: AnyPublisher<MusicTrack?, Never> { get }

    /// Whether the service is connected/authorized
    var isConnected: Bool { get }

    /// Service type identifier
    var serviceType: MusicServiceType { get }

    /// Request authorization for the music service
    func requestAuthorization() async throws

    /// Play current track or resume playback
    func play() async throws

    /// Pause playback
    func pause() async throws

    /// Skip to next track
    func skipToNext() async throws

    /// Skip to previous track
    func skipToPrevious() async throws

    /// Set playback volume (0.0 - 1.0)
    func setVolume(_ volume: Float) async

    /// Get current volume
    var currentVolume: Float { get }
}

// MARK: - Music Service Type

enum MusicServiceType: String, Codable, CaseIterable, Identifiable {
    case appleMusic = "apple_music"
    case spotify = "spotify"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .none: return "Ninguno"
        }
    }

    var iconName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "antenna.radiowaves.left.and.right"
        case .none: return "speaker.slash"
        }
    }
}

// MARK: - Playback State

enum MusicPlaybackState: Equatable {
    case playing
    case paused
    case stopped
    case interrupted
    case loading
    case unknown

    var isPlaying: Bool {
        self == .playing
    }

    var canPlay: Bool {
        self == .paused || self == .stopped
    }

    var canPause: Bool {
        self == .playing
    }
}

// MARK: - Music Track

struct MusicTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: URL?
    let artworkData: Data?

    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkURL: URL? = nil,
        artworkData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.artworkData = artworkData
    }

    static func == (lhs: MusicTrack, rhs: MusicTrack) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Music Errors

enum MusicError: LocalizedError {
    case notAuthorized
    case authorizationDenied
    case serviceUnavailable
    case playbackFailed(underlying: Error?)
    case notConnected
    case spotifyNotInstalled
    case tokenExpired
    case networkError

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "No autorizado para acceder al servicio de música"
        case .authorizationDenied:
            return "Permiso denegado para acceder a la música"
        case .serviceUnavailable:
            return "El servicio de música no está disponible"
        case .playbackFailed(let error):
            return "Error de reproducción: \(error?.localizedDescription ?? "desconocido")"
        case .notConnected:
            return "No conectado al servicio de música"
        case .spotifyNotInstalled:
            return "Spotify no está instalado"
        case .tokenExpired:
            return "La sesión ha expirado"
        case .networkError:
            return "Error de conexión"
        }
    }
}

// MARK: - Music Controller Configuration

struct MusicControllerConfig: Codable, Equatable {
    var preferredService: MusicServiceType
    var musicVolume: Float
    var duckDuringAnnouncements: Bool
    var duckingLevel: Float // Volume reduction (0.0-1.0, lower = more reduction)

    static let `default` = MusicControllerConfig(
        preferredService: .spotify,
        musicVolume: 0.7,
        duckDuringAnnouncements: true,
        duckingLevel: 0.3
    )
}

// MARK: - Mock Implementation

final class MockMusicController: MusicControllerProtocol {
    private let playbackStateSubject = CurrentValueSubject<MusicPlaybackState, Never>(.stopped)
    private let nowPlayingSubject = CurrentValueSubject<MusicTrack?, Never>(nil)

    var playbackState: AnyPublisher<MusicPlaybackState, Never> {
        playbackStateSubject.eraseToAnyPublisher()
    }

    var nowPlaying: AnyPublisher<MusicTrack?, Never> {
        nowPlayingSubject.eraseToAnyPublisher()
    }

    var isConnected: Bool = true
    var serviceType: MusicServiceType = .appleMusic
    var currentVolume: Float = 0.7

    // Test helpers
    var playCallCount = 0
    var pauseCallCount = 0
    var skipNextCallCount = 0
    var skipPreviousCallCount = 0

    func requestAuthorization() async throws {
        // No-op for mock
    }

    func play() async throws {
        playCallCount += 1
        playbackStateSubject.send(.playing)
    }

    func pause() async throws {
        pauseCallCount += 1
        playbackStateSubject.send(.paused)
    }

    func skipToNext() async throws {
        skipNextCallCount += 1
    }

    func skipToPrevious() async throws {
        skipPreviousCallCount += 1
    }

    func setVolume(_ volume: Float) async {
        currentVolume = volume
    }

    // Test simulation methods
    func simulateNowPlaying(_ track: MusicTrack?) {
        nowPlayingSubject.send(track)
    }

    func simulatePlaybackState(_ state: MusicPlaybackState) {
        playbackStateSubject.send(state)
    }
}
