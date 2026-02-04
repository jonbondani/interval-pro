import SwiftUI
import Combine

/// View for pairing with Garmin devices
struct GarminPairingView: View {
    @StateObject private var viewModel = GarminPairingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDebugLog = false
    @State private var hasShownConnectedMessage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    connectionStatusHeader

                    switch viewModel.connectionState {
                    case .disconnected, .failed:
                        disconnectedContent
                    case .scanning:
                        scanningContent
                    case .connecting:
                        connectingContent
                    case .connected:
                        connectedContent
                    case .reconnecting:
                        reconnectingContent
                    }

                    // Debug section
                    debugSection
                        .padding(.top, DesignTokens.Spacing.xl)
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .navigationTitle("Garmin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDebugLog.toggle()
                    } label: {
                        Image(systemName: "ladybug")
                            .foregroundStyle(showDebugLog ? .orange : .secondary)
                    }
                }
            }
            .onChange(of: viewModel.connectionState) { _, newState in
                // Auto-dismiss after 2 seconds when connected
                if case .connected = newState, !hasShownConnectedMessage {
                    hasShownConnectedMessage = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Connection Status Header
    private var connectionStatusHeader: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(viewModel.connectionState.isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: viewModel.connectionState.isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch")
                    .font(.system(size: 40))
                    .foregroundStyle(viewModel.connectionState.isConnected ? .green : .gray)
            }

            Text(viewModel.connectionState.displayText)
                .font(.headline)
                .foregroundStyle(viewModel.connectionState.isConnected ? .green : .secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    // MARK: - Disconnected Content
    private var disconnectedContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Conecta tu Garmin para obtener datos de frecuencia cardíaca y cadencia en tiempo real.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            // Quick tip
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Activa 'Transmitir FC' en tu reloj antes de buscar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Button {
                Task {
                    await viewModel.startScanning()
                }
            } label: {
                Label("Buscar dispositivos", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Button {
                Task {
                    await viewModel.findPairedGarmin()
                }
            } label: {
                Label("Usar Garmin ya enlazado", systemImage: "link.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            Button {
                Task {
                    await viewModel.startDeepScan()
                }
            } label: {
                Label("Búsqueda profunda (90s)", systemImage: "waveform.badge.magnifyingglass")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            if case .failed(let error) = viewModel.connectionState {
                ErrorBanner(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Scanning Content
    private var scanningContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Buscando dispositivos BLE...")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Dispositivos encontrados: \(viewModel.discoveredDevices.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.discoveredDevices.isEmpty {
                hrBroadcastInstructions
            } else {
                deviceList
            }

            Button("Detener búsqueda") {
                viewModel.stopScanning()
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - HR Broadcast Instructions
    private var hrBroadcastInstructions: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Para conectar tu Garmin Fenix 3HR:")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                instructionRow(number: 1, text: "Mantén pulsado UP en el reloj")
                instructionRow(number: 2, text: "Ve a Configuración > Sensores")
                instructionRow(number: 3, text: "Selecciona 'Transmitir FC'")
                instructionRow(number: 4, text: "Elige 'Transmitir durante actividad' o 'Transmitir'")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Importante:")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text("• El icono ❤️ con ondas debe aparecer en el reloj")
                    .font(.caption)
                Text("• Algunos modelos solo transmiten DURANTE una actividad")
                    .font(.caption)
                Text("• Inicia una actividad de carrera en el reloj si no aparece")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.top, DesignTokens.Spacing.xs)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        .padding(.horizontal)
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Device List
    private var deviceList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("Dispositivos encontrados")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ForEach(viewModel.discoveredDevices) { device in
                DeviceRow(device: device) {
                    Task {
                        try? await viewModel.connect(to: device.id)
                    }
                }
            }
        }
        .padding(.top)
    }

    // MARK: - Connecting Content
    private var connectingContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Conectando...")
                .font(.headline)

            Text("Estableciendo conexión con tu dispositivo.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Connected Content
    private var connectedContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            if let deviceName = viewModel.connectedDeviceName {
                Text(deviceName)
                    .font(.title2.bold())
            }

            Text("Dispositivo conectado y listo.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Live data display
            VStack(spacing: DesignTokens.Spacing.md) {
                if viewModel.currentHeartRate > 0 {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(viewModel.currentHeartRate)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("lpm")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.currentCadence > 0 {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.blue)
                        Text("\(viewModel.currentCadence)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("spm")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()

            Button(role: .destructive) {
                viewModel.disconnect()
            } label: {
                Text("Desconectar")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Reconnecting Content
    private var reconnectingContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            if case .reconnecting(let attempt) = viewModel.connectionState {
                Text("Reconectando... (Intento \(attempt)/3)")
                    .font(.headline)
            }

            Text("La conexión se perdió. Intentando reconectar automáticamente.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Cancelar") {
                viewModel.disconnect()
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Debug Section
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Button {
                showDebugLog.toggle()
            } label: {
                HStack {
                    Image(systemName: "ladybug")
                    Text("Debug Log")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showDebugLog ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(.primary)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
            }
            .padding(.horizontal)

            if showDebugLog {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Log de Bluetooth")
                            .font(.caption.bold())
                        Spacer()
                        Button("Limpiar") {
                            viewModel.clearDebugLog()
                        }
                        .font(.caption)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.debugLog.enumerated()), id: \.offset) { _, log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    let device: DiscoveredDevice
    let onTap: () -> Void

    private var iconColor: Color {
        if device.isGarmin { return .orange }
        if device.hasHRService { return .red }
        if device.hasRSCService { return .green }
        return .blue
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: device.statusIcon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        // Service badges
                        if device.isGarmin {
                            Badge(text: "GARMIN", color: .orange)
                        }
                        if device.hasHRService {
                            Badge(text: "HR", color: .red)
                        }
                        if device.hasRSCService {
                            Badge(text: "RSC", color: .green)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: device.signalStrength.icon)
                            .font(.caption)
                        Text("RSSI: \(device.rssi) dBm")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    Text(device.id.prefix(12) + "...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(device.isGarmin || device.hasHRService ?
                        Color.green.opacity(0.05) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .stroke(device.isGarmin || device.hasHRService ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
        .padding(.horizontal)
    }
}

// MARK: - ViewModel
@MainActor
final class GarminPairingViewModel: ObservableObject {
    @Published var connectionState: GarminConnectionState = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var currentHeartRate: Int = 0
    @Published var currentCadence: Int = 0
    @Published var debugLog: [String] = []

    private let garminManager: GarminManager
    private var cancellables = Set<AnyCancellable>()

    var connectedDeviceName: String? {
        garminManager.connectedDeviceName
    }

    init(garminManager: GarminManager = GarminManager.shared) {
        self.garminManager = garminManager
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        garminManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        garminManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredDevices)

        garminManager.$debugLog
            .receive(on: DispatchQueue.main)
            .assign(to: &$debugLog)

        garminManager.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentHeartRate)

        garminManager.cadencePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentCadence)
    }

    func startScanning() async {
        await garminManager.startScanning()
    }

    func startDeepScan() async {
        await garminManager.startDeepScan()
    }

    func findPairedGarmin() async {
        await garminManager.findPairedGarmin()
    }

    func stopScanning() {
        garminManager.stopScanning()
    }

    func connect(to deviceId: String) async throws {
        try await garminManager.connect(to: deviceId)
    }

    func inspectDevice(_ deviceId: String) async {
        await garminManager.inspectDevice(deviceId)
    }

    func disconnect() {
        garminManager.disconnect()
    }

    func clearDebugLog() {
        garminManager.clearDebugLog()
    }
}

// MARK: - Previews
#Preview("Disconnected") {
    GarminPairingView()
}
