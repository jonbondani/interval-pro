import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var navigationRouter: NavigationRouter

    var body: some View {
        Group {
            if appState.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home
        case progress
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }
                .tag(Tab.home)

            ProgressDashboardView()
                .tabItem {
                    Label("Progreso", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject private var navigationRouter: NavigationRouter
    @State private var selectedPlan: TrainingPlan?

    private let plans = TrainingPlan.defaultTemplates

    var body: some View {
        NavigationStack(path: $navigationRouter.homePath) {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header
                    headerSection

                    // Quick Start Section
                    quickStartSection

                    // Training Plans Section
                    plansSection

                    // Version Footer
                    versionFooter
                }
                .padding()
            }
            .navigationTitle("IntervalPro")
            .navigationDestination(for: NavigationRouter.Destination.self) { destination in
                switch destination {
                case .training:
                    if let plan = selectedPlan {
                        TrainingView(plan: plan)
                    }
                default:
                    EmptyView()
                }
            }
            .fullScreenCover(item: $selectedPlan) { plan in
                TrainingView(plan: plan)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Entrenamiento por Intervalos")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Quick Start Section
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Inicio Rápido")
                .font(.title2.bold())

            Button {
                selectedPlan = TrainingPlan.recommended
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Entrenamiento Recomendado")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Pirámide 160-170-180 BPM")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .padding(DesignTokens.Spacing.lg)
                .background(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
            }
            .accessibleTapTarget()
        }
    }

    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Planes de Entrenamiento")
                .font(.title2.bold())

            ForEach(plans) { plan in
                PlanCard(plan: plan) {
                    selectedPlan = plan
                }
            }
        }
    }

    // MARK: - Version Footer
    private var versionFooter: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.md)

            Text("IntervalPro v\(AppVersion.version) (\(AppVersion.build))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(AppVersion.buildDate)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: TrainingPlan
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(plan.name)
                        .font(.headline)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Label("\(plan.seriesCount) series", systemImage: "repeat")
                        Label(plan.totalDurationFormatted, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onStart) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(planColor(for: plan))
                }
                .accessibleTapTarget()
            }

            // Plan details
            HStack(spacing: DesignTokens.Spacing.lg) {
                DetailBadge(
                    icon: "figure.run",
                    value: formatDuration(plan.workDuration),
                    label: "Trabajo"
                )

                DetailBadge(
                    icon: "figure.stand",
                    value: formatDuration(plan.restDuration),
                    label: "Descanso"
                )

                DetailBadge(
                    icon: "heart.fill",
                    value: "\(plan.workZone.targetBPM)",
                    label: "BPM"
                )
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }

    private func planColor(for plan: TrainingPlan) -> Color {
        switch plan.name {
        case "Principiante": return .green
        case "Intermedio": return .orange
        case "Avanzado": return .red
        default: return .blue
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if seconds == 0 {
            return "\(minutes)min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Detail Badge
struct DetailBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressDashboardView: View {
    var body: some View {
        NavigationStack {
            Text("Progreso")
                .navigationTitle("Progreso")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showGarminPairing = false
    @StateObject private var garminManager = GarminManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Connection Status Section
                Section("Estado de Conexión") {
                    // Garmin status
                    Button {
                        showGarminPairing = true
                    } label: {
                        HStack {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .foregroundStyle(garminManager.isConnected ? .green : .orange)

                            VStack(alignment: .leading) {
                                Text("Garmin")
                                    .foregroundStyle(.primary)
                                Text(garminManager.connectionState.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Info Section
                Section("Información") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Los entrenamientos se guardan localmente en la app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Debug Section
                Section("Debug") {
                    Button("Reiniciar Onboarding") {
                        appState.resetOnboarding()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Perfil")
            .sheet(isPresented: $showGarminPairing) {
                GarminPairingView()
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var garminManager = GarminManager.shared
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showGarminPairing = false

    enum OnboardingStep {
        case welcome
        case garmin  // HealthKit removed - requires paid dev account
    }

    var body: some View {
        VStack(spacing: 32) {
            switch currentStep {
            case .welcome:
                welcomeContent

            case .garmin:
                garminSetupContent
            }
        }
        .sheet(isPresented: $showGarminPairing) {
            GarminPairingView()
        }
        .onChange(of: garminManager.connectionState) { _, newState in
            // Auto-complete onboarding when Garmin connects
            if case .connected = newState {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    appState.completeOnboarding()
                }
            }
        }
    }

    // MARK: - Welcome Content
    private var welcomeContent: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Bienvenido a IntervalPro")
                .font(.title.bold())

            Text("Entrena por intervalos con precisión basada en tu cadencia y frecuencia cardíaca")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                currentStep = .garmin
            } label: {
                Text("Comenzar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Garmin Setup Content
    private var garminSetupContent: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }

            Text("Conecta tu Garmin")
                .font(.title.bold())

            Text("Conecta tu reloj Garmin para obtener datos de cadencia y frecuencia cardíaca en tiempo real.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(icon: "1.circle.fill", text: "Activa 'Transmitir FC' en tu Garmin")
                instructionRow(icon: "2.circle.fill", text: "Mantén el reloj cerca del iPhone")
                instructionRow(icon: "3.circle.fill", text: "Pulsa 'Conectar Garmin' abajo")
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showGarminPairing = true
                } label: {
                    Label("Conectar Garmin", systemImage: "applewatch")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    appState.completeOnboarding()
                } label: {
                    Text("Continuar sin Garmin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Previews
#Preview("Main Tab View") {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(NavigationRouter())
}

#Preview("Onboarding") {
    let appState = AppState()
    appState.resetOnboarding()
    return ContentView()
        .environmentObject(appState)
        .environmentObject(NavigationRouter())
}
