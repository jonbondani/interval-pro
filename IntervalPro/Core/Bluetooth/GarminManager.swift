import Foundation
import CoreBluetooth
import Combine

/// Garmin device manager using CoreBluetooth
/// Per CLAUDE.md: Handles disconnection with exponential backoff and HealthKit fallback
@MainActor
final class GarminManager: NSObject, ObservableObject, GarminManaging {
    // MARK: - Singleton
    static let shared = GarminManager()

    // MARK: - BLE Service UUIDs
    private enum ServiceUUID {
        /// Standard Heart Rate Service
        static let heartRate = CBUUID(string: "180D")
        /// Heart Rate Measurement Characteristic
        static let heartRateMeasurement = CBUUID(string: "2A37")
        /// Running Speed and Cadence Service
        static let runningSpeedCadence = CBUUID(string: "1814")
        /// RSC Measurement Characteristic
        static let rscMeasurement = CBUUID(string: "2A53")
    }

    // MARK: - Published State
    @Published private(set) var connectionState: GarminConnectionState = .disconnected
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var lastConnectedDeviceId: String?

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var rscCharacteristic: CBCharacteristic?

    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var scanTimeout: Task<Void, Never>?

    // MARK: - Constants
    private let maxReconnectAttempts = 3
    private let baseReconnectDelay: TimeInterval = 2.0
    private let scanTimeoutSeconds: TimeInterval = 30.0

    // MARK: - Subjects
    private let connectionStateSubject = CurrentValueSubject<GarminConnectionState, Never>(.disconnected)
    private let heartRateSubject = PassthroughSubject<Int, Never>()
    private let paceSubject = PassthroughSubject<Double, Never>()
    private let speedSubject = PassthroughSubject<Double, Never>()
    private let cadenceSubject = PassthroughSubject<Int, Never>()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let lastDeviceId = "garmin_last_device_id"
        static let lastDeviceName = "garmin_last_device_name"
    }

    // MARK: - Protocol Publishers
    var connectionStatePublisher: AnyPublisher<GarminConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var heartRatePublisher: AnyPublisher<Int, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    var pacePublisher: AnyPublisher<Double, Never> {
        paceSubject.eraseToAnyPublisher()
    }

    var speedPublisher: AnyPublisher<Double, Never> {
        speedSubject.eraseToAnyPublisher()
    }

    var cadencePublisher: AnyPublisher<Int, Never> {
        cadenceSubject.eraseToAnyPublisher()
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    var connectedDeviceName: String? {
        if case .connected(let name) = connectionState {
            return name
        }
        return nil
    }

    // MARK: - Init
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        centralManager.delegate = self

        // Load last connected device
        lastConnectedDeviceId = UserDefaults.standard.string(forKey: Keys.lastDeviceId)

        Log.bluetooth.debug("GarminManager initialized")
    }

    // MARK: - Scanning
    func startScanning() async {
        guard centralManager.state == .poweredOn else {
            Log.bluetooth.warning("Bluetooth not powered on, cannot scan")
            updateConnectionState(.failed(.bluetoothOff))
            return
        }

        discoveredDevices = []
        updateConnectionState(.scanning)

        centralManager.scanForPeripherals(
            withServices: [ServiceUUID.heartRate],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        Log.bluetooth.info("Started scanning for Garmin devices")

        // Set scan timeout
        scanTimeout?.cancel()
        scanTimeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(scanTimeoutSeconds))
            if case .scanning = self.connectionState {
                self.stopScanning()
                if self.discoveredDevices.isEmpty {
                    self.updateConnectionState(.failed(.deviceNotFound))
                }
            }
        }
    }

    func stopScanning() {
        scanTimeout?.cancel()
        scanTimeout = nil

        guard centralManager.isScanning else { return }

        centralManager.stopScan()

        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }

        Log.bluetooth.debug("Stopped scanning")
    }

    // MARK: - Connection
    func connect(to deviceId: String) async throws {
        stopScanning()
        reconnectTask?.cancel()

        guard let device = discoveredDevices.first(where: { $0.id == deviceId }) else {
            // Try to retrieve known peripheral
            if let uuid = UUID(uuidString: deviceId),
               let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
                updateConnectionState(.connecting)
                centralManager.connect(peripheral, options: nil)
                return
            }
            throw GarminError.deviceNotFound
        }

        guard let peripheral = getPeripheral(for: device) else {
            throw GarminError.deviceNotFound
        }

        updateConnectionState(.connecting)
        centralManager.connect(peripheral, options: nil)

        Log.bluetooth.info("Connecting to device: \(device.name)")
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0

        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        cleanup()
        updateConnectionState(.disconnected)

        Log.bluetooth.info("Disconnected from device")
    }

    // MARK: - AutoLap
    func sendLapMarker() async {
        // Note: Standard BLE HR service doesn't support lap markers
        // This would require Garmin-specific Connect IQ integration
        // For now, we log the intent and the lap is tracked locally

        Log.bluetooth.debug("Lap marker requested (local tracking)")

        // If we had Garmin Connect IQ SDK:
        // try await garminConnectIQ.sendMessage(["type": "lap"])

        // Post notification for local handling
        NotificationCenter.default.post(
            name: .garminLapMarkerSent,
            object: nil,
            userInfo: ["timestamp": Date()]
        )
    }

    // MARK: - Reconnection Logic
    /// Per CLAUDE.md: Automatic reconnection with exponential backoff
    private func handleDisconnection(peripheral: CBPeripheral, error: Error?) {
        Log.bluetooth.warning("Device disconnected: \(error?.localizedDescription ?? "unknown")")

        guard reconnectAttempt < maxReconnectAttempts else {
            Log.bluetooth.error("Max reconnection attempts reached")
            cleanup()
            updateConnectionState(.failed(.maxReconnectAttemptsExceeded))
            notifyFallbackToHealthKit()
            return
        }

        reconnectAttempt += 1
        updateConnectionState(.reconnecting(attempt: reconnectAttempt))

        reconnectTask = Task { @MainActor in
            let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
            Log.bluetooth.debug("Reconnection attempt \(self.reconnectAttempt) in \(delay)s")

            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            self.centralManager.connect(peripheral, options: nil)
        }
    }

    private func notifyFallbackToHealthKit() {
        NotificationCenter.default.post(
            name: .garminFallbackActivated,
            object: nil
        )

        Log.bluetooth.info("Fallback to HealthKit activated")
    }

    // MARK: - State Management
    private func updateConnectionState(_ state: GarminConnectionState) {
        connectionState = state
        connectionStateSubject.send(state)
    }

    private func cleanup() {
        connectedPeripheral = nil
        heartRateCharacteristic = nil
        rscCharacteristic = nil
    }

    private func saveLastConnectedDevice(_ peripheral: CBPeripheral) {
        let defaults = UserDefaults.standard
        defaults.set(peripheral.identifier.uuidString, forKey: Keys.lastDeviceId)
        defaults.set(peripheral.name, forKey: Keys.lastDeviceName)
        lastConnectedDeviceId = peripheral.identifier.uuidString
    }

    private func getPeripheral(for device: DiscoveredDevice) -> CBPeripheral? {
        guard let uuid = UUID(uuidString: device.id) else { return nil }
        return centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
    }

    // MARK: - Data Parsing
    private func parseHeartRate(from data: Data) -> Int? {
        guard data.count >= 2 else { return nil }

        let bytes = [UInt8](data)
        let flags = bytes[0]

        // Bit 0 of flags indicates format:
        // 0 = UINT8 (1 byte), 1 = UINT16 (2 bytes)
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 && data.count >= 3 {
            return Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        } else {
            return Int(bytes[1])
        }
    }

    private func parseRSCMeasurement(from data: Data) {
        guard data.count >= 4 else { return }

        let bytes = [UInt8](data)
        let flags = bytes[0]

        var offset = 1

        // Instantaneous Speed (mandatory) - uint16, 1/256 m/s
        let speedRaw = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        let speedMS = Double(speedRaw) / 256.0
        let speedKMH = speedMS * 3.6
        offset += 2

        // Calculate pace (min/km)
        let paceSecPerKm = speedMS > 0 ? 1000.0 / speedMS : 0
        paceSubject.send(paceSecPerKm)
        speedSubject.send(speedKMH)

        // Instantaneous Cadence (optional, bit 0 of flags)
        if (flags & 0x01) != 0 && data.count >= offset + 1 {
            let cadence = Int(bytes[offset])
            cadenceSubject.send(cadence)
            offset += 1
        }

        Log.bluetooth.debug("RSC: speed=\(String(format: "%.1f", speedKMH))km/h, pace=\(String(format: "%.0f", paceSecPerKm))s/km")
    }
}

// MARK: - CBCentralManagerDelegate
extension GarminManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                Log.bluetooth.info("Bluetooth powered on")
                // Auto-reconnect to last device if available
                if let lastId = lastConnectedDeviceId,
                   let uuid = UUID(uuidString: lastId),
                   let peripheral = central.retrievePeripherals(withIdentifiers: [uuid]).first {
                    updateConnectionState(.connecting)
                    central.connect(peripheral, options: nil)
                }
            case .poweredOff:
                Log.bluetooth.warning("Bluetooth powered off")
                cleanup()
                updateConnectionState(.failed(.bluetoothOff))
            case .unauthorized:
                Log.bluetooth.error("Bluetooth unauthorized")
                updateConnectionState(.failed(.bluetoothUnauthorized))
            case .unsupported:
                Log.bluetooth.error("Bluetooth unsupported")
                updateConnectionState(.failed(.bluetoothOff))
            case .resetting:
                Log.bluetooth.warning("Bluetooth resetting")
            case .unknown:
                Log.bluetooth.debug("Bluetooth state unknown")
            @unknown default:
                break
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"

            // Filter for Garmin devices
            guard name.lowercased().contains("garmin") ||
                  name.lowercased().contains("fenix") ||
                  name.lowercased().contains("forerunner") else {
                return
            }

            let device = DiscoveredDevice(
                id: peripheral.identifier.uuidString,
                name: name,
                rssi: RSSI.intValue
            )

            if !discoveredDevices.contains(where: { $0.id == device.id }) {
                discoveredDevices.append(device)
                Log.bluetooth.debug("Discovered: \(name) (RSSI: \(RSSI))")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        Task { @MainActor in
            Log.bluetooth.info("Connected to: \(peripheral.name ?? "Unknown")")

            connectedPeripheral = peripheral
            peripheral.delegate = self
            reconnectAttempt = 0

            saveLastConnectedDevice(peripheral)
            updateConnectionState(.connected(deviceName: peripheral.name ?? "Garmin"))

            // Discover services
            peripheral.discoverServices([
                ServiceUUID.heartRate,
                ServiceUUID.runningSpeedCadence
            ])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            Log.bluetooth.error("Failed to connect: \(error?.localizedDescription ?? "unknown")")
            handleDisconnection(peripheral: peripheral, error: error)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            handleDisconnection(peripheral: peripheral, error: error)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension GarminManager: CBPeripheralDelegate {
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                Log.bluetooth.error("Service discovery error: \(error)")
                return
            }

            guard let services = peripheral.services else { return }

            for service in services {
                Log.bluetooth.debug("Discovered service: \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                Log.bluetooth.error("Characteristic discovery error: \(error)")
                return
            }

            guard let characteristics = service.characteristics else { return }

            for characteristic in characteristics {
                Log.bluetooth.debug("Discovered characteristic: \(characteristic.uuid)")

                if characteristic.uuid == ServiceUUID.heartRateMeasurement {
                    heartRateCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    Log.bluetooth.info("Subscribed to heart rate notifications")
                }

                if characteristic.uuid == ServiceUUID.rscMeasurement {
                    rscCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    Log.bluetooth.info("Subscribed to RSC notifications")
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                Log.bluetooth.error("Characteristic update error: \(error)")
                return
            }

            guard let data = characteristic.value else { return }

            if characteristic.uuid == ServiceUUID.heartRateMeasurement {
                if let bpm = parseHeartRate(from: data) {
                    // Validate HR range
                    guard bpm >= 30 && bpm <= 250 else {
                        Log.bluetooth.warning("Invalid HR filtered: \(bpm)")
                        return
                    }
                    Log.logHeartRate(bpm, context: "Garmin")
                    heartRateSubject.send(bpm)
                }
            }

            if characteristic.uuid == ServiceUUID.rscMeasurement {
                parseRSCMeasurement(from: data)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                Log.bluetooth.error("Notification state error: \(error)")
                return
            }

            Log.bluetooth.debug("Notification state updated for \(characteristic.uuid): \(characteristic.isNotifying)")
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let garminFallbackActivated = Notification.Name("garminFallbackActivated")
    static let garminLapMarkerSent = Notification.Name("garminLapMarkerSent")
}
