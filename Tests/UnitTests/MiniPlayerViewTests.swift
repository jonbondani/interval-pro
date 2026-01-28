import XCTest
import SwiftUI
@testable import IntervalPro

/// Tests for MiniPlayerView and related components
final class MiniPlayerViewTests: XCTestCase {

    // MARK: - MusicTrack Display Tests

    func test_musicTrack_withAllFields_displaysCorrectly() {
        let track = MusicTrack(
            id: "spotify:track:123",
            title: "Lose Yourself",
            artist: "Eminem",
            album: "8 Mile",
            duration: 326,
            artworkURL: URL(string: "https://example.com/art.jpg"),
            artworkData: nil
        )

        XCTAssertEqual(track.title, "Lose Yourself")
        XCTAssertEqual(track.artist, "Eminem")
        XCTAssertEqual(track.album, "8 Mile")
        XCTAssertEqual(track.duration, 326)
    }

    func test_musicTrack_withoutOptionalFields_displaysCorrectly() {
        let track = MusicTrack(
            id: "1",
            title: "Unknown Track",
            artist: "Unknown Artist"
        )

        XCTAssertEqual(track.title, "Unknown Track")
        XCTAssertEqual(track.artist, "Unknown Artist")
        XCTAssertNil(track.album)
        XCTAssertNil(track.artworkURL)
        XCTAssertNil(track.artworkData)
    }

    // MARK: - Service Color Tests

    func test_serviceColors_areDistinct() {
        // Verify service types have distinct colors for UI differentiation
        let appleColor = serviceColor(for: .appleMusic)
        let spotifyColor = serviceColor(for: .spotify)
        let noneColor = serviceColor(for: .none)

        // Colors should be different
        XCTAssertNotEqual(appleColor.description, spotifyColor.description)
        XCTAssertNotEqual(appleColor.description, noneColor.description)
    }

    private func serviceColor(for service: MusicServiceType) -> Color {
        switch service {
        case .appleMusic: return .pink
        case .spotify: return .green
        case .none: return .gray
        }
    }

    // MARK: - Config Tests

    func test_musicControllerConfig_duckingBounds() {
        var config = MusicControllerConfig.default

        // Ducking level should be between 0.1 and 0.5 for reasonable ducking
        XCTAssertGreaterThanOrEqual(config.duckingLevel, 0.0)
        XCTAssertLessThanOrEqual(config.duckingLevel, 1.0)

        // Test at boundaries
        config.duckingLevel = 0.1
        XCTAssertEqual(config.duckingLevel, 0.1)

        config.duckingLevel = 0.5
        XCTAssertEqual(config.duckingLevel, 0.5)
    }

    func test_musicControllerConfig_volumeBounds() {
        var config = MusicControllerConfig.default

        XCTAssertGreaterThanOrEqual(config.musicVolume, 0.0)
        XCTAssertLessThanOrEqual(config.musicVolume, 1.0)

        config.musicVolume = 0.0
        XCTAssertEqual(config.musicVolume, 0.0)

        config.musicVolume = 1.0
        XCTAssertEqual(config.musicVolume, 1.0)
    }

    // MARK: - Playback State Tests

    func test_playbackState_descriptions() {
        // Verify all states have expected behavior
        let states: [MusicPlaybackState] = [.playing, .paused, .stopped, .interrupted, .loading, .unknown]

        for state in states {
            // Each state should have defined behavior
            _ = state.isPlaying
            _ = state.canPlay
            _ = state.canPause
        }

        // Specific assertions
        XCTAssertTrue(MusicPlaybackState.playing.isPlaying)
        XCTAssertTrue(MusicPlaybackState.paused.canPlay)
        XCTAssertTrue(MusicPlaybackState.playing.canPause)
    }
}

// MARK: - View Snapshot Tests (placeholder)

/// Note: Full UI snapshot testing would require additional setup with snapshot testing library
/// These tests verify the view model state affects UI as expected

final class MiniPlayerViewModelTests: XCTestCase {

    @MainActor
    func test_noTrack_showsNoPlayingMessage() async {
        let mock = MockMusicController()
        mock.simulateNowPlaying(nil)

        // When no track is playing, nowPlaying should be nil
        var receivedTrack: MusicTrack?
        let expectation = expectation(description: "Receive track")

        mock.nowPlaying
            .first()
            .sink { track in
                receivedTrack = track
                expectation.fulfill()
            }
            .store(in: &MockCancellables.set)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNil(receivedTrack)
    }

    @MainActor
    func test_playingTrack_showsTrackInfo() async {
        let mock = MockMusicController()
        let track = MusicTrack(
            id: "1",
            title: "Test Song",
            artist: "Test Artist"
        )

        var receivedTrack: MusicTrack?
        let expectation = expectation(description: "Receive track")

        mock.nowPlaying
            .dropFirst() // Skip initial nil
            .first()
            .sink { track in
                receivedTrack = track
                expectation.fulfill()
            }
            .store(in: &MockCancellables.set)

        mock.simulateNowPlaying(track)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTrack?.title, "Test Song")
        XCTAssertEqual(receivedTrack?.artist, "Test Artist")
    }

    @MainActor
    func test_playbackControls_reflectState() async {
        let mock = MockMusicController()

        // Initially stopped
        var currentState: MusicPlaybackState = .stopped

        mock.playbackState
            .sink { state in
                currentState = state
            }
            .store(in: &MockCancellables.set)

        // Simulate playing
        mock.simulatePlaybackState(.playing)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(currentState.isPlaying)

        // Simulate paused
        mock.simulatePlaybackState(.paused)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(currentState.canPlay)
    }
}

// Helper for test cancellables
import Combine
private enum MockCancellables {
    static var set = Set<AnyCancellable>()
}
