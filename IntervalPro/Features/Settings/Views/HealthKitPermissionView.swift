import SwiftUI
import HealthKit

/// View for requesting HealthKit permissions
struct HealthKitPermissionView: View {
    @StateObject private var viewModel = HealthKitPermissionViewModel()
    @Environment(\.dismiss) private var dismiss

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
            }

            // Title
            Text("Acceso a Salud")
                .font(.title.bold())

            // Description
            Text("IntervalPro necesita acceso a tus datos de frecuencia cardíaca para:")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Features list
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                FeatureRow(
                    icon: "waveform.path.ecg",
                    title: "Monitorear tu FC en tiempo real",
                    description: "Durante tus entrenamientos"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Analizar tu progreso",
                    description: "Comparar sesiones históricas"
                )

                FeatureRow(
                    icon: "figure.run",
                    title: "Guardar entrenamientos",
                    description: "Sincronizar con la app Salud"
                )
            }
            .padding(.horizontal)

            Spacer()

            // Status message
            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(viewModel.isError ? .red : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            VStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    Task {
                        await viewModel.requestPermission()
                        // Continue regardless of result - HealthKit is optional
                        // Garmin is the primary data source
                        onComplete()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.isAuthorized ? "Continuar" : "Permitir acceso")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isAuthorized ? .green : .blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
                .disabled(viewModel.isLoading)

                Button("Saltar este paso") {
                    // HealthKit is optional - Garmin is primary
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ViewModel
@MainActor
final class HealthKitPermissionViewModel: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = false
    @Published var statusMessage: String?
    @Published var isError: Bool = false

    private let healthKitManager: HealthKitManaging

    init(healthKitManager: HealthKitManaging = HealthKitManager.shared) {
        self.healthKitManager = healthKitManager
        self.isAuthorized = healthKitManager.isAuthorized
    }

    func requestPermission() async {
        isLoading = true
        isError = false
        statusMessage = nil

        do {
            try await healthKitManager.requestAuthorization()
            isAuthorized = healthKitManager.isAuthorized

            if isAuthorized {
                statusMessage = "Acceso concedido"
            } else {
                statusMessage = "Acceso denegado. Puedes cambiarlo en Ajustes > Salud."
                isError = true
            }
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    HealthKitPermissionView {
        // On complete
    }
}
