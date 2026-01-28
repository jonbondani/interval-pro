import XCTest
import Combine
@testable import IntervalPro

/// Tests for MetronomeEngine using MockAudioEngine
final class MetronomeEngineTests: XCTestCase {

    var sut: MockAudioEngine!

    override func setUp() {
        super.setUp()
        sut = MockAudioEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State
    func test_initialState_isNotRunning() {
        XCTAssertFalse(sut.isMetronomeRunning)
        XCTAssertTrue(sut.isVoiceEnabled)
    }

    // MARK: - Start Metronome
    func test_startMetronome_setsRunningState() throws {
        try sut.startMetronome(bpm: 170, volume: 0.7, soundType: .click)

        XCTAssertTrue(sut.isMetronomeRunning)
        XCTAssertEqual(sut.currentBPM, 170)
        XCTAssertEqual(sut.currentVolume, 0.7)
    }

    // MARK: - Stop Metronome
    func test_stopMetronome_clearsRunningState() throws {
        try sut.startMetronome(bpm: 170, volume: 0.7, soundType: .click)
        sut.stopMetronome()

        XCTAssertFalse(sut.isMetronomeRunning)
    }

    // MARK: - Update BPM
    func test_updateMetronomeBPM_changesValue() throws {
        try sut.startMetronome(bpm: 170, volume: 0.7, soundType: .click)

        sut.updateMetronomeBPM(180)

        XCTAssertEqual(sut.currentBPM, 180)
    }

    // MARK: - Update Volume
    func test_updateMetronomeVolume_changesValue() throws {
        try sut.startMetronome(bpm: 170, volume: 0.7, soundType: .click)

        sut.updateMetronomeVolume(0.9)

        XCTAssertEqual(sut.currentVolume, 0.9)
    }

    // MARK: - Voice Announcements
    func test_announce_storesMessage() async {
        await sut.announce("Test message")

        XCTAssertEqual(sut.lastAnnouncedMessage, "Test message")
    }

    func test_announcePhaseChange_announcesCorrectMessage() async {
        await sut.announcePhaseChange(.work)

        XCTAssertEqual(sut.lastAnnouncedMessage, IntervalPhase.work.startAnnouncement)
    }

    func test_announceTimeWarning_announcesSeconds() async {
        await sut.announceTimeWarning(secondsRemaining: 30)

        XCTAssertEqual(sut.lastAnnouncedMessage, "30 segundos")
    }

    func test_announceZoneStatus_announcesInstruction() async {
        await sut.announceZoneStatus(.belowZone(by: 10))

        XCTAssertEqual(sut.lastAnnouncedMessage, "Sube intensidad (+10 bpm)")
    }

    // MARK: - Audio Session
    func test_configureAudioSession_completes() throws {
        try sut.configureAudioSession()
        // Should not throw
    }

    func test_deactivateAudioSession_completes() {
        sut.deactivateAudioSession()
        // Should not throw
    }
}

// MARK: - MetronomeSoundType Tests
final class MetronomeSoundTypeTests: XCTestCase {

    func test_allCases_exist() {
        XCTAssertEqual(MetronomeSoundType.allCases.count, 3)
        XCTAssertTrue(MetronomeSoundType.allCases.contains(.click))
        XCTAssertTrue(MetronomeSoundType.allCases.contains(.beep))
        XCTAssertTrue(MetronomeSoundType.allCases.contains(.woodblock))
    }

    func test_displayName_returnsLocalizedString() {
        XCTAssertEqual(MetronomeSoundType.click.displayName, "Click")
        XCTAssertEqual(MetronomeSoundType.beep.displayName, "Beep")
        XCTAssertEqual(MetronomeSoundType.woodblock.displayName, "Madera")
    }

    func test_fileName_returnsCorrectFile() {
        XCTAssertEqual(MetronomeSoundType.click.fileName, "metronome_click")
        XCTAssertEqual(MetronomeSoundType.beep.fileName, "metronome_beep")
        XCTAssertEqual(MetronomeSoundType.woodblock.fileName, "metronome_woodblock")
    }

    func test_identifiable_usesRawValue() {
        XCTAssertEqual(MetronomeSoundType.click.id, "click")
    }
}

// MARK: - MetronomeConfig Tests
final class MetronomeConfigTests: XCTestCase {

    func test_defaultConfig_hasExpectedValues() {
        let config = MetronomeConfig.default

        XCTAssertEqual(config.bpm, 170)
        XCTAssertEqual(config.volume, 0.7)
        XCTAssertEqual(config.soundType, .click)
        XCTAssertTrue(config.isEnabled)
    }

    func test_validatedBPM_clampsToRange() {
        var config = MetronomeConfig.default

        config.bpm = 50
        XCTAssertEqual(config.validatedBPM, 100)

        config.bpm = 300
        XCTAssertEqual(config.validatedBPM, 220)

        config.bpm = 170
        XCTAssertEqual(config.validatedBPM, 170)
    }

    func test_codable_encodesAndDecodes() throws {
        let config = MetronomeConfig(
            bpm: 180,
            volume: 0.8,
            soundType: .beep,
            isEnabled: false
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MetronomeConfig.self, from: data)

        XCTAssertEqual(config, decoded)
    }
}

// MARK: - VoiceConfig Tests
final class VoiceConfigTests: XCTestCase {

    func test_defaultConfig_hasExpectedValues() {
        let config = VoiceConfig.default

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.volume, 0.9)
        XCTAssertEqual(config.language, "es-ES")
    }

    func test_codable_encodesAndDecodes() throws {
        let config = VoiceConfig(
            isEnabled: false,
            volume: 0.5,
            language: "en-US"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VoiceConfig.self, from: data)

        XCTAssertEqual(config, decoded)
    }
}
