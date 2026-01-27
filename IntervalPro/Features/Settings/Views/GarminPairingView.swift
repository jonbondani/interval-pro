import SwiftUI

/// View for pairing with Garmin devices
struct GarminPairingView: View {
    @StateObject private var viewModel = GarminPairingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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

                Spacer()
            }
            .navigationTitle("Garmin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
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
            Text("Conecta tu Garmin Fenix para obtener datos de frecuencia cardíaca en tiempo real durante tus entrenamientos.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

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

            Text("Buscando dispositivos Garmin...")
                .font(.body)
                .foregroundStyle(.secondary)

            if viewModel.discoveredDevices.isEmpty {
                Text("Asegúrate de que tu Garmin esté encendido y cerca.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                deviceList
            }

            Button("Cancelar") {
                viewModel.stopScanning()
            }
            .foregroundStyle(.red)
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
                        try await viewModel.connect(to: device.id)
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

            Text("Estableciendo conexión con tu dispositivo Garmin.")
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

            Text("Tu dispositivo está conectado y listo para transmitir datos.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Live HR display
            if viewModel.currentHeartRate > 0 {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(viewModel.currentHeartRate)")
                        .font(DesignTokens.Typography.hrDisplay)
                    Text("BPM")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

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
}

// MARK: - Device Row
struct DeviceRow: View {
    let device: DiscoveredDevice
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: device.signalStrength.icon)
                            .font(.caption)
                        Text("Señal: \(signalText)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var signalText: String {
        switch device.signalStrength {
        case .excellent: return "Excelente"
        case .good: return "Buena"
        case .fair: return "Regular"
        case .weak: return "Débil"
        }
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

    private let garminManager: GarminManaging
    private var cancellables = Set<AnyCancellable>()

    var connectedDeviceName: String? {
        garminManager.connectedDeviceName
    }

    init(garminManager: GarminManaging = GarminManager.shared) {
        self.garminManager = garminManager
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        garminManager.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        garminManager.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentHeartRate)

        // For discovered devices, we need to observe GarminManager directly
        if let manager = garminManager as? GarminManager {
            manager.$discoveredDevices
                .receive(on: DispatchQueue.main)
                .assign(to: &$discoveredDevices)
        }
    }

    func startScanning() async {
        await garminManager.startScanning()
    }

    func stopScanning() {
        garminManager.stopScanning()
    }

    func connect(to deviceId: String) async throws {
        try await garminManager.connect(to: deviceId)
    }

    func disconnect() {
        garminManager.disconnect()
    }
}

// MARK: - Previews
#Preview("Disconnected") {
    GarminPairingView()
}

#Preview("Scanning with devices") {
    let view = GarminPairingView()
    return view
}
