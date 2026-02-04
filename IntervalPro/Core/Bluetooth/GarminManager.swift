import Foundation
import CoreBluetooth
import Combine

/// Garmin device manager using CoreBluetooth
/// Supports standard BLE Heart Rate (0x180D) and Running Speed & Cadence (0x1814)
///
/// IMPORTANT: Garmin Fenix 3HR requirements:
/// 1. Enable "Broadcast Heart Rate" on the watch: Settings > Sensors > Broadcast HR
/// 2. The watch will then advertise as a BLE HR sensor
/// 3. Device name may vary - could be "Fenix 3 HR", "GARMIN", or custom name
@MainActor
final class GarminManager: NSObject, ObservableObject, GarminManaging {
    // MARK: - Singleton
    static let shared = GarminManager()

    // MARK: - BLE Service UUIDs (Standard Bluetooth SIG)
    private enum ServiceUUID {
        /// Heart Rate Service (standard BLE)
        static let heartRate = CBUUID(string: "180D")
        /// Heart Rate Measurement Characteristic
        static let heartRateMeasurement = CBUUID(string: "2A37")
        /// Running Speed and Cadence Service
        static let runningSpeedCadence = CBUUID(string: "1814")
        /// RSC Measurement Characteristic
        static let rscMeasurement = CBUUID(string: "2A53")
        /// Device Information Service
        static let deviceInfo = CBUUID(string: "180A")
        /// Battery Service
        static let battery = CBUUID(string: "180F")

        // Garmin proprietary services (used by Garmin Connect)
        static let garminProprietary1 = CBUUID(string: "6A4E2800-667B-11E3-949A-0800200C9A66")
        static let garminProprietary2 = CBUUID(string: "6A4E2801-667B-11E3-949A-0800200C9A66")
        static let garminFenixService = CBUUID(string: "6A4ECADE-667B-11E3-949A-0800200C9A66")

        // Additional HR sensor services (some devices use these)
        static let customHR1 = CBUUID(string: "0000FEE0-0000-1000-8000-00805F9B34FB") // Mi Band style
        static let customHR2 = CBUUID(string: "0000FEE1-0000-1000-8000-00805F9B34FB")
    }

    // MARK: - Published State
    @Published private(set) var connectionState: GarminConnectionState = .disconnected
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var lastConnectedDeviceId: String?
    @Published private(set) var debugLog: [String] = []

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var rscCharacteristic: CBCharacteristic?
    private var allDiscoveredPeripherals: [UUID: CBPeripheral] = [:]

    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var scanTimeout: Task<Void, Never>?
    private var isDeepScanMode = false

    // MARK: - Constants
    private let maxReconnectAttempts = 3
    private let baseReconnectDelay: TimeInterval = 2.0
    private let scanTimeoutSeconds: TimeInterval = 60.0  // Extended for debugging

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

        addDebugLog("🔧 GarminManager inicializando...")

        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        centralManager = CBCentralManager(delegate: nil, queue: nil, options: options)
        centralManager.delegate = self

        lastConnectedDeviceId = UserDefaults.standard.string(forKey: Keys.lastDeviceId)
        if let lastId = lastConnectedDeviceId {
            addDebugLog("📱 Último dispositivo guardado: \(lastId)")
        }

        Log.bluetooth.info("GarminManager initialized")
    }

    // MARK: - Debug Logging
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        debugLog.append(logEntry)
        Log.bluetooth.info("\(message)")

        // Keep only last 100 entries
        if debugLog.count > 100 {
            debugLog.removeFirst()
        }
    }

    // MARK: - Scanning
    func startScanning() async {
        addDebugLog("🔍 Iniciando búsqueda de dispositivos BLE...")

        guard centralManager.state == .poweredOn else {
            addDebugLog("❌ Bluetooth no está encendido (estado: \(centralManager.state.rawValue))")
            updateConnectionState(.failed(.bluetoothOff))
            return
        }

        discoveredDevices = []
        allDiscoveredPeripherals = [:]
        updateConnectionState(.scanning)

        // STEP 1: Check for already connected peripherals with HR service
        addDebugLog("📡 Buscando periféricos ya conectados con servicio HR (0x180D)...")
        let hrConnected = centralManager.retrieveConnectedPeripherals(withServices: [ServiceUUID.heartRate])
        addDebugLog("   → Encontrados con HR: \(hrConnected.count)")
        for p in hrConnected {
            addDebugLog("   → HR: '\(p.name ?? "Sin nombre")' ID: \(p.identifier)")
        }

        // STEP 2: Check for connected peripherals with RSC service
        addDebugLog("📡 Buscando periféricos con servicio RSC (0x1814)...")
        let rscConnected = centralManager.retrieveConnectedPeripherals(withServices: [ServiceUUID.runningSpeedCadence])
        addDebugLog("   → Encontrados con RSC: \(rscConnected.count)")
        for p in rscConnected {
            addDebugLog("   → RSC: '\(p.name ?? "Sin nombre")' ID: \(p.identifier)")
        }

        // STEP 3: Try to retrieve last known device
        if let lastId = lastConnectedDeviceId, let uuid = UUID(uuidString: lastId) {
            addDebugLog("📡 Buscando último dispositivo conocido: \(lastId)")
            let known = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = known.first {
                addDebugLog("   → ✅ Encontrado: '\(peripheral.name ?? "Sin nombre")'")
                addDebugLog("   → Intentando conectar...")
                updateConnectionState(.connecting)
                centralManager.connect(peripheral, options: nil)
                return
            } else {
                addDebugLog("   → ❌ No encontrado en memoria")
            }
        }

        // STEP 4: Auto-connect if we found HR-capable peripherals
        let allConnected = hrConnected + rscConnected
        if let first = allConnected.first {
            addDebugLog("🔗 Auto-conectando a: '\(first.name ?? "Sin nombre")'")
            let device = DiscoveredDevice(
                id: first.identifier.uuidString,
                name: first.name ?? "HR Device",
                rssi: -50
            )
            discoveredDevices.append(device)
            allDiscoveredPeripherals[first.identifier] = first
            updateConnectionState(.connecting)
            centralManager.connect(first, options: nil)
            return
        }

        // STEP 5: Start scanning for ALL devices (no service filter)
        addDebugLog("📡 Escaneando TODOS los dispositivos BLE...")
        addDebugLog("   (El Fenix debe tener 'Transmitir FC' activado)")

        centralManager.scanForPeripherals(
            withServices: nil,  // Scan ALL devices
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )

        // Set scan timeout
        scanTimeout?.cancel()
        scanTimeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(scanTimeoutSeconds))
            if case .scanning = self.connectionState {
                self.addDebugLog("⏱️ Timeout de escaneo alcanzado")
                self.addDebugLog("📊 Total dispositivos encontrados: \(self.discoveredDevices.count)")
                self.stopScanning()
                if self.discoveredDevices.isEmpty {
                    self.updateConnectionState(.failed(.deviceNotFound))
                }
            }
        }
    }

    /// Scan specifically for HR service (more targeted)
    func scanForHRDevices() async {
        addDebugLog("🎯 Escaneando solo dispositivos con HR Service (0x180D)...")

        guard centralManager.state == .poweredOn else {
            addDebugLog("❌ Bluetooth no disponible")
            return
        }

        centralManager.scanForPeripherals(
            withServices: [ServiceUUID.heartRate],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    /// Deep scan - logs ALL devices including weak signals
    func startDeepScan() async {
        isDeepScanMode = true
        addDebugLog("🔬 DEEP SCAN - Mostrando TODOS los dispositivos BLE...")
        addDebugLog("═══════════════════════════════════════════════════")

        guard centralManager.state == .poweredOn else {
            addDebugLog("❌ Bluetooth no disponible")
            return
        }

        discoveredDevices = []
        allDiscoveredPeripherals = [:]
        updateConnectionState(.scanning)

        // FIRST: Try to find the already-paired Garmin
        await findPairedGarmin()

        // Scan all BLE devices
        addDebugLog("📡 Escaneando todos los dispositivos BLE...")

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true  // Allow duplicates to see all ads
            ]
        )

        // Extended timeout for deep scan
        scanTimeout?.cancel()
        scanTimeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(90))
            if case .scanning = self.connectionState {
                self.addDebugLog("⏱️ Deep scan completado: \(self.discoveredDevices.count) dispositivos")
                self.stopScanning()
            }
        }
    }

    /// Try to find the Garmin that's already paired to iOS
    func findPairedGarmin() async {
        addDebugLog("🔍 Buscando Garmin ya conectado...")
        updateConnectionState(.scanning)

        let found = searchAllKnownServices()
        addDebugLog("📊 Dispositivos encontrados: \(found.count)")

        if found.isEmpty {
            logNoDevicesFound()
            updateConnectionState(.disconnected)
        } else {
            await connectToFoundPeripherals(found)
        }
    }

    private func searchAllKnownServices() -> [CBPeripheral] {
        // All known BLE service UUIDs (standard + Garmin proprietary)
        let serviceUUIDs: [String] = [
            // Standard services
            "180D", "1814", "180F", "180A", "1800", "1801", "1805", "1811", "1812", "1816", "1818",
            // Garmin proprietary
            "6A4E2800-667B-11E3-949A-0800200C9A66", "6A4E2801-667B-11E3-949A-0800200C9A66",
            "6A4E3200-667B-11E3-949A-0800200C9A66", "6A4ECADE-667B-11E3-949A-0800200C9A66",
            // Apple services (ANCS for notifications)
            "7905F431-B5CE-4E99-A40F-4B1E122D00D0", "89D3502B-0F36-433A-8EF4-C502AD55F8DC"
        ]

        var found: [CBPeripheral] = []
        addDebugLog("🔎 Probando \(serviceUUIDs.count) servicios...")

        for uuidString in serviceUUIDs {
            let uuid = CBUUID(string: uuidString)
            let connected = centralManager.retrieveConnectedPeripherals(withServices: [uuid])

            for peripheral in connected where !found.contains(where: { $0.identifier == peripheral.identifier }) {
                found.append(peripheral)
                addDebugLog("✅ '\(peripheral.name ?? "?")' via \(uuidString.prefix(8))")
            }
        }
        return found
    }

    private func connectToFoundPeripherals(_ peripherals: [CBPeripheral]) async {
        addDebugLog("🔗 Conectando para descubrir servicios...")

        for peripheral in peripherals {
            let name = peripheral.name ?? "Dispositivo"
            allDiscoveredPeripherals[peripheral.identifier] = peripheral

            if !discoveredDevices.contains(where: { $0.id == peripheral.identifier.uuidString }) {
                let isGarmin = name.lowercased().contains("garmin") || name.lowercased().contains("fenix")
                discoveredDevices.append(DiscoveredDevice(
                    id: peripheral.identifier.uuidString, name: name, rssi: -40,
                    hasHRService: false, hasRSCService: false, isGarmin: isGarmin
                ))
            }

            addDebugLog("🔗 Conectando a '\(name)'...")
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func logNoDevicesFound() {
        addDebugLog("❌ No se encontró dispositivo BLE. Usa 'Búsqueda profunda'.")
    }

    /// Try to connect to any device by ID (for manual inspection)
    func inspectDevice(_ deviceId: String) async {
        addDebugLog("🔍 Inspeccionando dispositivo: \(deviceId.prefix(12))...")

        guard let peripheral = allDiscoveredPeripherals.values.first(where: { $0.identifier.uuidString == deviceId }) else {
            addDebugLog("❌ Dispositivo no encontrado en caché")

            // Try to retrieve from system
            if let uuid = UUID(uuidString: deviceId) {
                let retrieved = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let p = retrieved.first {
                    addDebugLog("   → Recuperado del sistema: '\(p.name ?? "Sin nombre")'")
                    allDiscoveredPeripherals[p.identifier] = p
                    centralManager.connect(p, options: nil)
                    return
                }
            }
            return
        }

        addDebugLog("   → Conectando para inspeccionar servicios...")
        stopScanning()
        updateConnectionState(.connecting)
        centralManager.connect(peripheral, options: nil)
    }

    func stopScanning() {
        scanTimeout?.cancel()
        scanTimeout = nil
        isDeepScanMode = false

        guard centralManager.isScanning else { return }

        centralManager.stopScan()
        addDebugLog("🛑 Escaneo detenido")

        if case .scanning = connectionState {
            updateConnectionState(.disconnected)
        }
    }

    /// Auto-reconnect to last known device or find via Garmin services
    private func autoReconnect() async {
        // Try saved UUID first, then Garmin proprietary service
        if let lastId = lastConnectedDeviceId, let uuid = UUID(uuidString: lastId),
           let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            connectToPeripheral(peripheral, reason: "último dispositivo")
            return
        }

        let garminUUID = CBUUID(string: "6A4E2800-667B-11E3-949A-0800200C9A66")
        if let peripheral = centralManager.retrieveConnectedPeripherals(withServices: [garminUUID]).first {
            saveLastConnectedDevice(peripheral)
            connectToPeripheral(peripheral, reason: "servicio Garmin")
            return
        }
        addDebugLog("📱 No hay dispositivo previo")
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral, reason: String) {
        addDebugLog("🔄 Conectando (\(reason)): \(peripheral.name ?? "?")")
        allDiscoveredPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        updateConnectionState(.connecting)
        centralManager.connect(peripheral, options: nil)
    }

    // MARK: - Connection
    func connect(to deviceId: String) async throws {
        addDebugLog("🔗 Conectando a dispositivo: \(deviceId)")
        stopScanning()
        reconnectTask?.cancel()

        // Try from discovered devices first
        if let peripheral = allDiscoveredPeripherals.values.first(where: { $0.identifier.uuidString == deviceId }) {
            updateConnectionState(.connecting)
            centralManager.connect(peripheral, options: nil)
            return
        }

        // Try to retrieve by UUID
        if let uuid = UUID(uuidString: deviceId),
           let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            addDebugLog("   → Recuperado de sistema: '\(peripheral.name ?? "Unknown")'")
            updateConnectionState(.connecting)
            centralManager.connect(peripheral, options: nil)
            return
        }

        addDebugLog("❌ Dispositivo no encontrado: \(deviceId)")
        throw GarminError.deviceNotFound
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0

        if let peripheral = connectedPeripheral {
            addDebugLog("🔌 Desconectando de: '\(peripheral.name ?? "Unknown")'")
            centralManager.cancelPeripheralConnection(peripheral)
        }

        cleanup()
        updateConnectionState(.disconnected)
    }

    // MARK: - AutoLap
    func sendLapMarker() async {
        addDebugLog("🏃 Lap marker (solo local)")
        NotificationCenter.default.post(
            name: .garminLapMarkerSent,
            object: nil,
            userInfo: ["timestamp": Date()]
        )
    }

    // MARK: - Reconnection Logic
    private func handleDisconnection(peripheral: CBPeripheral, error: Error?) {
        addDebugLog("⚠️ Desconexión: \(error?.localizedDescription ?? "sin error")")

        guard reconnectAttempt < maxReconnectAttempts else {
            addDebugLog("❌ Máximo de reconexiones alcanzado")
            cleanup()
            updateConnectionState(.failed(.maxReconnectAttemptsExceeded))
            notifyFallbackToSimulation()
            return
        }

        reconnectAttempt += 1
        updateConnectionState(.reconnecting(attempt: reconnectAttempt))

        reconnectTask = Task { @MainActor in
            let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))
            addDebugLog("🔄 Reconexión \(self.reconnectAttempt)/\(self.maxReconnectAttempts) en \(delay)s")

            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            self.centralManager.connect(peripheral, options: nil)
        }
    }

    private func notifyFallbackToSimulation() {
        NotificationCenter.default.post(name: .garminFallbackActivated, object: nil)
        addDebugLog("📱 Activando modo simulación como fallback")
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
        addDebugLog("💾 Guardado como último dispositivo")
    }

    // MARK: - Data Parsing
    private func parseHeartRate(from data: Data) -> Int? {
        guard data.count >= 2 else { return nil }

        let bytes = [UInt8](data)
        let flags = bytes[0]
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

        // Speed (uint16, 1/256 m/s)
        let speedRaw = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        let speedMS = Double(speedRaw) / 256.0
        let speedKMH = speedMS * 3.6
        offset += 2

        let paceSecPerKm = speedMS > 0 ? 1000.0 / speedMS : 0
        paceSubject.send(paceSecPerKm)
        speedSubject.send(speedKMH)

        // Cadence (optional)
        if (flags & 0x01) != 0 && data.count >= offset + 1 {
            let cadence = Int(bytes[offset])
            cadenceSubject.send(cadence)
            addDebugLog("📊 RSC: \(cadence) spm, \(String(format: "%.1f", speedKMH)) km/h")
        }
    }

    // MARK: - Debug Helper
    func clearDebugLog() {
        debugLog.removeAll()
    }

    func getSystemBluetoothInfo() -> String {
        var info = "=== Sistema Bluetooth ===\n"
        info += "Estado: \(centralManager.state.rawValue)\n"
        info += "Escaneando: \(centralManager.isScanning)\n"
        info += "Dispositivos descubiertos: \(discoveredDevices.count)\n"
        info += "Periférico conectado: \(connectedPeripheral?.name ?? "ninguno")\n"
        return info
    }
}

// MARK: - CBCentralManagerDelegate
extension GarminManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            let stateNames = ["unknown", "resetting", "unsupported", "unauthorized", "poweredOff", "poweredOn"]
            let stateName = central.state.rawValue < stateNames.count ? stateNames[Int(central.state.rawValue)] : "?"

            addDebugLog("📶 Bluetooth estado: \(stateName) (\(central.state.rawValue))")

            switch central.state {
            case .poweredOn:
                addDebugLog("✅ Bluetooth listo")
                // Auto-reconnect to last device or find via Garmin services
                await autoReconnect()

            case .poweredOff:
                addDebugLog("❌ Bluetooth apagado")
                cleanup()
                updateConnectionState(.failed(.bluetoothOff))

            case .unauthorized:
                addDebugLog("⛔ Bluetooth no autorizado - revisa Ajustes > Privacidad > Bluetooth")
                updateConnectionState(.failed(.bluetoothUnauthorized))

            case .unsupported:
                addDebugLog("❌ Bluetooth no soportado en este dispositivo")
                updateConnectionState(.failed(.bluetoothOff))

            default:
                addDebugLog("⏳ Estado: \(stateName)")
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
            let name = peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
                ?? "Unknown"

            // Get advertised services
            let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            let overflowServices = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []
            let allServices = serviceUUIDs + overflowServices

            // Check manufacturer data (Garmin uses this)
            let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
            var manufacturerInfo = ""
            if let data = manufacturerData {
                let bytes = [UInt8](data)
                if bytes.count >= 2 {
                    let companyId = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
                    manufacturerInfo = "Mfr:\(String(format: "0x%04X", companyId))"
                    // Garmin company ID is 0x0087 (135)
                    if companyId == 0x0087 {
                        manufacturerInfo += " [GARMIN!]"
                    }
                }
            }

            // Check if has HR/RSC/Garmin services
            let hasHRService = allServices.contains(ServiceUUID.heartRate)
            let hasRSCService = allServices.contains(ServiceUUID.runningSpeedCadence)
            let hasGarminService = allServices.contains(ServiceUUID.garminProprietary1) ||
                                   allServices.contains(ServiceUUID.garminProprietary2) ||
                                   allServices.contains(ServiceUUID.garminFenixService)

            // Check TX Power (can help identify fitness devices)
            let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber

            // Check name patterns
            let nameLower = name.lowercased()
            let isLikelyGarmin = nameLower.contains("garmin") ||
                                 nameLower.contains("fenix") ||
                                 nameLower.contains("forerunner") ||
                                 nameLower.contains("vivoactive") ||
                                 nameLower.contains("venu") ||
                                 nameLower.contains("instinct") ||
                                 nameLower.contains("enduro") ||
                                 nameLower.contains("hrm") ||
                                 nameLower.contains("heart") ||
                                 nameLower.contains("polar") ||
                                 nameLower.contains("wahoo") ||
                                 nameLower.contains("tickr")

            // Detect by manufacturer ID
            let isGarminManufacturer = manufacturerInfo.contains("GARMIN") ||
                                       manufacturerInfo.contains("0x0087")

            // Check if connectable
            let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false

            // Store peripheral reference
            allDiscoveredPeripherals[peripheral.identifier] = peripheral

            // Log EVERY device with close RSSI or any interesting property
            let isStrong = RSSI.intValue > -70
            let isInteresting = hasHRService || hasRSCService || hasGarminService ||
                               isLikelyGarmin || isGarminManufacturer || isStrong

            // Build detailed log message
            var logMsg = "📱 '\(name)' RSSI:\(RSSI)"

            if !allServices.isEmpty {
                let serviceStrs = allServices.map { knownServiceName($0).isEmpty ? $0.uuidString : knownServiceName($0) }
                logMsg += "\n   Servicios: [\(serviceStrs.joined(separator: ", "))]"
            }

            if !manufacturerInfo.isEmpty {
                logMsg += "\n   \(manufacturerInfo)"
            }

            if let tx = txPower {
                logMsg += " TX:\(tx)"
            }

            if !isConnectable {
                logMsg += " [No conectable]"
            }

            // Add flags
            if hasHRService { logMsg += " ❤️HR" }
            if hasRSCService { logMsg += " 🏃RSC" }
            if hasGarminService { logMsg += " ⌚GARMIN-SVC" }
            if isLikelyGarmin { logMsg += " ⌚Garmin?" }
            if isGarminManufacturer { logMsg += " ⌚GARMIN-MFR!" }

            // Log if interesting OR if it's an unknown device with decent signal
            // Also log in deep scan mode for ANY connectable device
            if isInteresting || (name == "Unknown" && RSSI.intValue > -65) || (self.isDeepScanMode && isConnectable) {
                addDebugLog(logMsg)
            }

            // For Unknown devices with strong signal, add a detailed dump
            if name == "Unknown" && RSSI.intValue > -55 && isConnectable {
                addDebugLog("   ⚠️ Dispositivo desconocido con señal fuerte - podría ser Garmin!")
                addDebugLog("   ID: \(peripheral.identifier.uuidString)")
                // Log all advertisement keys
                for (key, value) in advertisementData {
                    addDebugLog("   Ad[\(key)]: \(value)")
                }
            }

            // Add to device list for manual inspection
            // Include ALL devices with decent signal for debugging
            let shouldAdd = hasHRService || hasRSCService || hasGarminService ||
                           isLikelyGarmin || isGarminManufacturer ||
                           (isConnectable && RSSI.intValue > -75)

            if shouldAdd && !discoveredDevices.contains(where: { $0.id == peripheral.identifier.uuidString }) {
                var displayName = name
                if isGarminManufacturer && name == "Unknown" {
                    displayName = "Garmin Device (Unknown)"
                }

                let device = DiscoveredDevice(
                    id: peripheral.identifier.uuidString,
                    name: displayName,
                    rssi: RSSI.intValue,
                    hasHRService: hasHRService,
                    hasRSCService: hasRSCService,
                    isGarmin: isLikelyGarmin || isGarminManufacturer || hasGarminService
                )
                discoveredDevices.append(device)
                addDebugLog("➕ Añadido a lista: '\(displayName)' (conectable:\(isConnectable))")

                // Auto-connect to definite HR/RSC devices
                if (hasHRService || hasRSCService) && connectedPeripheral == nil && isConnectable {
                    addDebugLog("🔗 Auto-conectando a dispositivo HR: '\(displayName)'")
                    stopScanning()
                    updateConnectionState(.connecting)
                    central.connect(peripheral, options: nil)
                }
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            addDebugLog("✅ CONECTADO a: '\(peripheral.name ?? "Unknown")'")

            connectedPeripheral = peripheral
            peripheral.delegate = self
            reconnectAttempt = 0

            saveLastConnectedDevice(peripheral)
            updateConnectionState(.connected(deviceName: peripheral.name ?? "HR Device"))

            // Discover ALL services first to see what's available
            addDebugLog("🔍 Descubriendo servicios...")
            peripheral.discoverServices(nil)  // Discover ALL services
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            addDebugLog("❌ Fallo de conexión: \(error?.localizedDescription ?? "desconocido")")
            handleDisconnection(peripheral: peripheral, error: error)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            handleDisconnection(peripheral: peripheral, error: error)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension GarminManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                addDebugLog("❌ Error descubriendo servicios: \(error.localizedDescription)")
                return
            }

            guard let services = peripheral.services else {
                addDebugLog("⚠️ No se encontraron servicios")
                return
            }

            addDebugLog("📋 Servicios encontrados: \(services.count)")
            for service in services {
                let name = knownServiceName(service.uuid)
                addDebugLog("   → \(service.uuid) \(name)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                addDebugLog("❌ Error características: \(error.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else { return }

            let serviceName = knownServiceName(service.uuid)
            addDebugLog("📋 Características de \(serviceName):")

            for char in characteristics {
                let charName = knownCharacteristicName(char.uuid)
                let props = characteristicPropertiesString(char.properties)
                addDebugLog("   → \(char.uuid) \(charName) [\(props)]")

                // Subscribe to HR measurement (standard)
                if char.uuid == ServiceUUID.heartRateMeasurement {
                    heartRateCharacteristic = char
                    peripheral.setNotifyValue(true, for: char)
                    addDebugLog("   ❤️ Suscrito a Heart Rate estándar!")
                }

                // Subscribe to RSC measurement (standard)
                if char.uuid == ServiceUUID.rscMeasurement {
                    rscCharacteristic = char
                    peripheral.setNotifyValue(true, for: char)
                    addDebugLog("   🏃 Suscrito a RSC estándar!")
                }

                // GARMIN PROPRIETARY: Subscribe to ALL characteristics with Notify
                // These might contain HR/sensor data in Garmin's format
                if char.properties.contains(.notify) {
                    let uuidStr = char.uuid.uuidString.uppercased()

                    // Garmin sensor data characteristics (6A4E25xx range)
                    if uuidStr.hasPrefix("6A4E25") || uuidStr.hasPrefix("6A4E28") ||
                       uuidStr.hasPrefix("6A4ECD") {
                        peripheral.setNotifyValue(true, for: char)
                        addDebugLog("   📡 Suscrito a Garmin: \(uuidStr.prefix(12))...")
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                addDebugLog("❌ Error actualizando valor: \(error.localizedDescription)")
                return
            }

            guard let data = characteristic.value else { return }

            let uuidStr = characteristic.uuid.uuidString.uppercased()

            // Standard Heart Rate
            if characteristic.uuid == ServiceUUID.heartRateMeasurement {
                if let bpm = parseHeartRate(from: data) {
                    guard bpm >= 30 && bpm <= 250 else { return }
                    addDebugLog("❤️ HR estándar: \(bpm) bpm")
                    heartRateSubject.send(bpm)
                }
                return
            }

            // Standard RSC
            if characteristic.uuid == ServiceUUID.rscMeasurement {
                parseRSCMeasurement(from: data)
                return
            }

            // GARMIN PROPRIETARY DATA - try to extract HR
            if uuidStr.hasPrefix("6A4E") {
                parseGarminProprietaryData(from: data, characteristic: uuidStr)
            }
        }
    }

    /// Try to parse Garmin's proprietary data format
    private func parseGarminProprietaryData(from data: Data, characteristic: String) {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else { return }

        // Characteristic 6A4E2501 = Heart Rate data (confirmed working)
        if characteristic.contains("2501") {
            guard bytes.count >= 2 else { return }
            let hr = Int(bytes[1])
            if hr >= 40 && hr <= 220 {
                addDebugLog("❤️ Garmin HR: \(hr) bpm")
                heartRateSubject.send(hr)
            }
            return
        }

        // NOTE: Characteristic 6A4E2502 format is unknown - disabling cadence parsing
        // The Fenix 3HR doesn't expose standard RSC service (0x1814)
        // Cadence will come from simulation or be disabled
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                addDebugLog("❌ Error notificación: \(error.localizedDescription)")
                return
            }

            let charName = knownCharacteristicName(characteristic.uuid)
            addDebugLog("🔔 Notificaciones \(characteristic.isNotifying ? "ON" : "OFF") para \(charName)")
        }
    }

    // MARK: - Helper: Known Service Names
    private func knownServiceName(_ uuid: CBUUID) -> String {
        switch uuid.uuidString.uppercased() {
        case "180D": return "(Heart Rate)"
        case "1814": return "(Running Speed & Cadence)"
        case "180A": return "(Device Information)"
        case "180F": return "(Battery)"
        case "1800": return "(Generic Access)"
        case "1801": return "(Generic Attribute)"
        default: return ""
        }
    }

    private func knownCharacteristicName(_ uuid: CBUUID) -> String {
        switch uuid.uuidString.uppercased() {
        case "2A37": return "(HR Measurement)"
        case "2A38": return "(Body Sensor Location)"
        case "2A39": return "(HR Control Point)"
        case "2A53": return "(RSC Measurement)"
        case "2A54": return "(RSC Feature)"
        case "2A19": return "(Battery Level)"
        case "2A29": return "(Manufacturer Name)"
        case "2A24": return "(Model Number)"
        default: return ""
        }
    }

    private func characteristicPropertiesString(_ props: CBCharacteristicProperties) -> String {
        var result: [String] = []
        if props.contains(.read) { result.append("R") }
        if props.contains(.write) { result.append("W") }
        if props.contains(.notify) { result.append("N") }
        if props.contains(.indicate) { result.append("I") }
        return result.joined(separator: ",")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let garminFallbackActivated = Notification.Name("garminFallbackActivated")
    static let garminLapMarkerSent = Notification.Name("garminLapMarkerSent")
}
