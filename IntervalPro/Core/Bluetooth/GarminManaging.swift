import Foundation
import Combine

/// Protocol for Garmin device management
/// Per CLAUDE.md: All managers must have protocol abstraction for DI
protocol GarminManaging: AnyObject {
    // MARK: - Publishers
    var connectionStatePublisher: AnyPublisher<GarminConnectionState, Never> { get }
    var heartRatePublisher: AnyPublisher<Int, Never> { get }
    var pacePublisher: AnyPublisher<Double, Never> { get }  // sec/km
    var speedPublisher: AnyPublisher<Double, Never> { get }  // km/h
    var cadencePublisher: AnyPublisher<Int, Never> { get }  // steps/min

    // MARK: - State
    var connectionState: GarminConnectionState { get }
    var isConnected: Bool { get }
    var connectedDeviceName: String? { get }

    // MARK: - Actions
    func startScanning() async
    func stopScanning()
    func connect(to deviceId: String) async throws
    func disconnect()
    func sendLapMarker() async
}

// MARK: - Connection State
enum GarminConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected(deviceName: String)
    case reconnecting(attempt: Int)
    case failed(GarminError)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return "Desconectado"
        case .scanning:
            return "Buscando..."
        case .connecting:
            return "Conectando..."
        case .connected(let name):
            return "Conectado: \(name)"
        case .reconnecting(let attempt):
            return "Reconectando (\(attempt)/3)..."
        case .failed(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Discovered Device
struct DiscoveredDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let rssi: Int  // Signal strength
    var hasHRService: Bool = false
    var hasRSCService: Bool = false
    var isGarmin: Bool = false

    var signalStrength: SignalStrength {
        switch rssi {
        case -50...0: return .excellent
        case -70..<(-50): return .good
        case -85..<(-70): return .fair
        default: return .weak
        }
    }

    var statusIcon: String {
        if isGarmin { return "applewatch.radiowaves.left.and.right" }
        if hasHRService { return "heart.fill" }
        if hasRSCService { return "figure.run" }
        return "antenna.radiowaves.left.and.right"
    }

    var statusColor: String {
        if isGarmin { return "orange" }
        if hasHRService || hasRSCService { return "green" }
        return "blue"
    }

    var subtitle: String {
        var parts: [String] = []
        if isGarmin { parts.append("Garmin") }
        if hasHRService { parts.append("HR") }
        if hasRSCService { parts.append("RSC") }
        if parts.isEmpty { return "Desconocido" }
        return parts.joined(separator: " + ")
    }

    enum SignalStrength {
        case excellent, good, fair, weak

        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .weak: return "wifi.slash"
            }
        }
    }
}

// MARK: - Errors
enum GarminError: LocalizedError, Equatable {
    case bluetoothOff
    case bluetoothUnauthorized
    case deviceNotFound
    case connectionFailed
    case connectionLost
    case maxReconnectAttemptsExceeded
    case unsupportedDevice
    case serviceNotFound
    case characteristicNotFound

    var errorDescription: String? {
        switch self {
        case .bluetoothOff:
            return "Bluetooth está desactivado. Actívalo en Ajustes."
        case .bluetoothUnauthorized:
            return "IntervalPro necesita permiso de Bluetooth. Actívalo en Ajustes."
        case .deviceNotFound:
            return "No se encontró el dispositivo Garmin."
        case .connectionFailed:
            return "No se pudo conectar al dispositivo."
        case .connectionLost:
            return "Se perdió la conexión con el dispositivo."
        case .maxReconnectAttemptsExceeded:
            return "No se pudo reconectar después de varios intentos."
        case .unsupportedDevice:
            return "Este dispositivo no es compatible."
        case .serviceNotFound:
            return "Servicio de frecuencia cardíaca no encontrado."
        case .characteristicNotFound:
            return "Característica de datos no encontrada."
        }
    }
}

// MARK: - Mock for Testing and Previews
final class MockGarminManager: GarminManaging {
    // MARK: - Subjects
    private let connectionStateSubject = CurrentValueSubject<GarminConnectionState, Never>(.disconnected)
    private let heartRateSubject = CurrentValueSubject<Int, Never>(0)
    private let paceSubject = CurrentValueSubject<Double, Never>(0)
    private let speedSubject = CurrentValueSubject<Double, Never>(0)
    private let cadenceSubject = CurrentValueSubject<Int, Never>(0)

    // MARK: - Publishers
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

    // MARK: - State
    var connectionState: GarminConnectionState {
        connectionStateSubject.value
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

    // MARK: - Mock Control
    var simulatedState: GarminConnectionState = .disconnected {
        didSet { connectionStateSubject.send(simulatedState) }
    }

    func simulateHeartRate(_ bpm: Int) {
        heartRateSubject.send(bpm)
    }

    func simulatePace(_ pace: Double) {
        paceSubject.send(pace)
    }

    // MARK: - Actions
    func startScanning() async {
        connectionStateSubject.send(.scanning)
    }

    func stopScanning() {
        connectionStateSubject.send(.disconnected)
    }

    func connect(to deviceId: String) async throws {
        connectionStateSubject.send(.connecting)
        try await Task.sleep(for: .milliseconds(500))
        connectionStateSubject.send(.connected(deviceName: "Mock Garmin Fenix 7"))
    }

    func disconnect() {
        connectionStateSubject.send(.disconnected)
    }

    func sendLapMarker() async {
        Log.bluetooth.debug("Mock: Lap marker sent")
    }
}
