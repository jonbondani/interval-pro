import XCTest
import Combine
@testable import IntervalPro

/// Tests for GarminManager using MockGarminManager
final class GarminManagerTests: XCTestCase {

    var sut: MockGarminManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = MockGarminManager()
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Connection State Tests
    func test_initialState_isDisconnected() {
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertFalse(sut.isConnected)
    }

    func test_startScanning_updatesStateToScanning() async {
        await sut.startScanning()

        XCTAssertEqual(sut.connectionState, .scanning)
    }

    func test_stopScanning_updatesStateToDisconnected() async {
        await sut.startScanning()
        sut.stopScanning()

        XCTAssertEqual(sut.connectionState, .disconnected)
    }

    func test_connect_updatesStateToConnected() async throws {
        try await sut.connect(to: "test-device-id")

        XCTAssertTrue(sut.isConnected)
        XCTAssertNotNil(sut.connectedDeviceName)
    }

    func test_disconnect_updatesStateToDisconnected() async throws {
        try await sut.connect(to: "test-device-id")
        sut.disconnect()

        XCTAssertFalse(sut.isConnected)
        XCTAssertNil(sut.connectedDeviceName)
    }

    // MARK: - Publisher Tests
    func test_connectionStatePublisher_emitsStateChanges() async {
        var states: [GarminConnectionState] = []

        sut.connectionStatePublisher
            .sink { state in
                states.append(state)
            }
            .store(in: &cancellables)

        await sut.startScanning()
        try? await sut.connect(to: "test")

        // Should have: disconnected (initial), scanning, connecting, connected
        XCTAssertTrue(states.count >= 3)
    }

    func test_heartRatePublisher_emitsSimulatedValues() {
        var receivedBPM: [Int] = []

        sut.heartRatePublisher
            .sink { bpm in
                receivedBPM.append(bpm)
            }
            .store(in: &cancellables)

        sut.simulateHeartRate(165)
        sut.simulateHeartRate(170)
        sut.simulateHeartRate(168)

        XCTAssertEqual(receivedBPM, [165, 170, 168])
    }

    func test_pacePublisher_emitsSimulatedValues() {
        var receivedPace: [Double] = []

        sut.pacePublisher
            .sink { pace in
                receivedPace.append(pace)
            }
            .store(in: &cancellables)

        sut.simulatePace(300.0)  // 5:00 min/km

        XCTAssertEqual(receivedPace.count, 1)
        XCTAssertEqual(receivedPace.first, 300.0)
    }

    // MARK: - Lap Marker Tests
    func test_sendLapMarker_completeWithoutError() async {
        await sut.sendLapMarker()
        // Should complete without throwing
    }

    // MARK: - Connection State Helpers
    func test_connectionState_isConnected_returnsCorrectValue() {
        XCTAssertFalse(GarminConnectionState.disconnected.isConnected)
        XCTAssertFalse(GarminConnectionState.scanning.isConnected)
        XCTAssertFalse(GarminConnectionState.connecting.isConnected)
        XCTAssertTrue(GarminConnectionState.connected(deviceName: "Test").isConnected)
        XCTAssertFalse(GarminConnectionState.reconnecting(attempt: 1).isConnected)
        XCTAssertFalse(GarminConnectionState.failed(.connectionLost).isConnected)
    }

    func test_connectionState_displayText_returnsLocalizedString() {
        XCTAssertEqual(GarminConnectionState.disconnected.displayText, "Desconectado")
        XCTAssertEqual(GarminConnectionState.scanning.displayText, "Buscando...")
        XCTAssertEqual(GarminConnectionState.connecting.displayText, "Conectando...")
        XCTAssertEqual(GarminConnectionState.connected(deviceName: "Fenix 7").displayText, "Conectado: Fenix 7")
        XCTAssertEqual(GarminConnectionState.reconnecting(attempt: 2).displayText, "Reconectando (2/3)...")
    }
}

// MARK: - DiscoveredDevice Tests
final class DiscoveredDeviceTests: XCTestCase {

    func test_signalStrength_excellent_forHighRSSI() {
        let device = DiscoveredDevice(id: "1", name: "Test", rssi: -40)
        XCTAssertEqual(device.signalStrength, .excellent)
    }

    func test_signalStrength_good_forMediumRSSI() {
        let device = DiscoveredDevice(id: "1", name: "Test", rssi: -60)
        XCTAssertEqual(device.signalStrength, .good)
    }

    func test_signalStrength_fair_forLowRSSI() {
        let device = DiscoveredDevice(id: "1", name: "Test", rssi: -75)
        XCTAssertEqual(device.signalStrength, .fair)
    }

    func test_signalStrength_weak_forVeryLowRSSI() {
        let device = DiscoveredDevice(id: "1", name: "Test", rssi: -90)
        XCTAssertEqual(device.signalStrength, .weak)
    }
}

// MARK: - GarminError Tests
final class GarminErrorTests: XCTestCase {

    func test_errorDescription_returnsLocalizedMessage() {
        XCTAssertNotNil(GarminError.bluetoothOff.errorDescription)
        XCTAssertNotNil(GarminError.bluetoothUnauthorized.errorDescription)
        XCTAssertNotNil(GarminError.deviceNotFound.errorDescription)
        XCTAssertNotNil(GarminError.connectionFailed.errorDescription)
        XCTAssertNotNil(GarminError.connectionLost.errorDescription)
        XCTAssertNotNil(GarminError.maxReconnectAttemptsExceeded.errorDescription)
    }

    func test_errorEquatable() {
        XCTAssertEqual(GarminError.bluetoothOff, GarminError.bluetoothOff)
        XCTAssertNotEqual(GarminError.bluetoothOff, GarminError.connectionLost)
    }
}
