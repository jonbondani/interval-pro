import XCTest
import Combine
@testable import IntervalPro

/// Tests for Music Controller components
final class MusicControllerTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - MusicServiceType Tests

    func test_musicServiceType_hasAllCases() {
        XCTAssertEqual(MusicServiceType.allCases.count, 3)
        XCTAssertTrue(MusicServiceType.allCases.contains(.appleMusic))
        XCTAssertTrue(MusicServiceType.allCases.contains(.spotify))
        XCTAssertTrue(MusicServiceType.allCases.contains(.none))
    }

    func test_musicServiceType_displayNames() {
        XCTAssertEqual(MusicServiceType.appleMusic.displayName, "Apple Music")
        XCTAssertEqual(MusicServiceType.spotify.displayName, "Spotify")
        XCTAssertEqual(MusicServiceType.none.displayName, "Ninguno")
    }

    func test_musicServiceType_iconNames() {
        XCTAssertEqual(MusicServiceType.appleMusic.iconName, "music.note")
        XCTAssertEqual(MusicServiceType.spotify.iconName, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(MusicServiceType.none.iconName, "speaker.slash")
    }

    func test_musicServiceType_identifiable() {
        XCTAssertEqual(MusicServiceType.appleMusic.id, "apple_music")
        XCTAssertEqual(MusicServiceType.spotify.id, "spotify")
        XCTAssertEqual(MusicServiceType.none.id, "none")
    }

    // MARK: - MusicPlaybackState Tests

    func test_playbackState_isPlaying() {
        XCTAssertTrue(MusicPlaybackState.playing.isPlaying)
        XCTAssertFalse(MusicPlaybackState.paused.isPlaying)
        XCTAssertFalse(MusicPlaybackState.stopped.isPlaying)
        XCTAssertFalse(MusicPlaybackState.interrupted.isPlaying)
    }

    func test_playbackState_canPlay() {
        XCTAssertTrue(MusicPlaybackState.paused.canPlay)
        XCTAssertTrue(MusicPlaybackState.stopped.canPlay)
        XCTAssertFalse(MusicPlaybackState.playing.canPlay)
    }

    func test_playbackState_canPause() {
        XCTAssertTrue(MusicPlaybackState.playing.canPause)
        XCTAssertFalse(MusicPlaybackState.paused.canPause)
        XCTAssertFalse(MusicPlaybackState.stopped.canPause)
    }

    // MARK: - MusicTrack Tests

    func test_musicTrack_initialization() {
        let track = MusicTrack(
            id: "test-id",
            title: "Test Song",
            artist: "Test Artist",
            album: "Test Album",
            duration: 240,
            artworkURL: URL(string: "https://example.com/art.jpg"),
            artworkData: nil
        )

        XCTAssertEqual(track.id, "test-id")
        XCTAssertEqual(track.title, "Test Song")
        XCTAssertEqual(track.artist, "Test Artist")
        XCTAssertEqual(track.album, "Test Album")
        XCTAssertEqual(track.duration, 240)
        XCTAssertNotNil(track.artworkURL)
    }

    func test_musicTrack_equality() {
        let track1 = MusicTrack(id: "123", title: "Song A", artist: "Artist")
        let track2 = MusicTrack(id: "123", title: "Song B", artist: "Different Artist")
        let track3 = MusicTrack(id: "456", title: "Song A", artist: "Artist")

        // Equality based on ID only
        XCTAssertEqual(track1, track2)
        XCTAssertNotEqual(track1, track3)
    }

    // MARK: - MusicControllerConfig Tests

    func test_config_defaultValues() {
        let config = MusicControllerConfig.default

        XCTAssertEqual(config.preferredService, .appleMusic)
        XCTAssertEqual(config.musicVolume, 0.7)
        XCTAssertTrue(config.duckDuringAnnouncements)
        XCTAssertEqual(config.duckingLevel, 0.3)
    }

    func test_config_codable() throws {
        let config = MusicControllerConfig(
            preferredService: .spotify,
            musicVolume: 0.8,
            duckDuringAnnouncements: false,
            duckingLevel: 0.5
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MusicControllerConfig.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    // MARK: - MusicError Tests

    func test_musicError_descriptions() {
        XCTAssertNotNil(MusicError.notAuthorized.errorDescription)
        XCTAssertNotNil(MusicError.authorizationDenied.errorDescription)
        XCTAssertNotNil(MusicError.serviceUnavailable.errorDescription)
        XCTAssertNotNil(MusicError.notConnected.errorDescription)
        XCTAssertNotNil(MusicError.spotifyNotInstalled.errorDescription)
        XCTAssertNotNil(MusicError.tokenExpired.errorDescription)
        XCTAssertNotNil(MusicError.networkError.errorDescription)
    }

    func test_musicError_playbackFailed_includesUnderlyingError() {
        let underlying = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = MusicError.playbackFailed(underlying: underlying)

        XCTAssertTrue(error.errorDescription?.contains("Test error") ?? false)
    }
}

// MARK: - MockMusicController Tests

final class MockMusicControllerTests: XCTestCase {

    var sut: MockMusicController!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = MockMusicController()
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }

    func test_initialState() {
        XCTAssertTrue(sut.isConnected)
        XCTAssertEqual(sut.serviceType, .appleMusic)
        XCTAssertEqual(sut.currentVolume, 0.7)
    }

    func test_play_updatesStateAndCallCount() async throws {
        var receivedStates: [MusicPlaybackState] = []

        sut.playbackState
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)

        try await sut.play()

        XCTAssertEqual(sut.playCallCount, 1)
        XCTAssertTrue(receivedStates.contains(.playing))
    }

    func test_pause_updatesStateAndCallCount() async throws {
        try await sut.play()
        try await sut.pause()

        XCTAssertEqual(sut.pauseCallCount, 1)
    }

    func test_skipToNext_incrementsCallCount() async throws {
        try await sut.skipToNext()
        try await sut.skipToNext()

        XCTAssertEqual(sut.skipNextCallCount, 2)
    }

    func test_skipToPrevious_incrementsCallCount() async throws {
        try await sut.skipToPrevious()

        XCTAssertEqual(sut.skipPreviousCallCount, 1)
    }

    func test_setVolume_clampsValue() async {
        await sut.setVolume(1.5)
        XCTAssertEqual(sut.currentVolume, 1.5) // Mock doesn't clamp

        await sut.setVolume(0.5)
        XCTAssertEqual(sut.currentVolume, 0.5)
    }

    func test_simulateNowPlaying_publishesTrack() async {
        var receivedTracks: [MusicTrack?] = []

        sut.nowPlaying
            .sink { track in
                receivedTracks.append(track)
            }
            .store(in: &cancellables)

        let track = MusicTrack(id: "1", title: "Test", artist: "Artist")
        sut.simulateNowPlaying(track)

        // Wait for publish
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(receivedTracks.contains { $0?.id == "1" })
    }

    func test_simulatePlaybackState_publishesState() async {
        var receivedStates: [MusicPlaybackState] = []

        sut.playbackState
            .sink { state in
                receivedStates.append(state)
            }
            .store(in: &cancellables)

        sut.simulatePlaybackState(.interrupted)

        // Wait for publish
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(receivedStates.contains(.interrupted))
    }
}

// MARK: - UnifiedMusicController Integration Tests

@MainActor
final class UnifiedMusicControllerIntegrationTests: XCTestCase {

    var sut: UnifiedMusicController!

    override func setUp() async throws {
        try await super.setUp()
        // Note: Integration tests with real controllers may fail without proper setup
        // These tests primarily verify the integration logic
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    func test_configPersistence() {
        // Create controller and modify config
        let controller1 = UnifiedMusicController.shared
        controller1.config.musicVolume = 0.85
        controller1.config.preferredService = .spotify

        // Config should be persisted (UserDefaults in test environment)
        XCTAssertEqual(controller1.config.musicVolume, 0.85)
        XCTAssertEqual(controller1.config.preferredService, .spotify)

        // Reset for other tests
        controller1.config = .default
    }

    func test_volumeBounds() async {
        let controller = UnifiedMusicController.shared

        await controller.setVolume(1.5)
        // Volume should be clamped
        XCTAssertLessThanOrEqual(controller.config.musicVolume, 1.0)

        await controller.setVolume(-0.5)
        XCTAssertGreaterThanOrEqual(controller.config.musicVolume, 0.0)

        // Reset
        controller.config = .default
    }
}
