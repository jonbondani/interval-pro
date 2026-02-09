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
    @StateObject private var sessionRepository = SessionRepository()
    @State private var sessions: [TrainingSession] = []
    @State private var selectedSession: TrainingSession?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando...")
                } else if sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("Progreso")
            .task {
                await loadSessions()
            }
            .refreshable {
                await loadSessions()
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Sin entrenamientos")
                .font(.title2.bold())

            Text("Completa tu primer entrenamiento para ver tu progreso aquí")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var sessionListView: some View {
        List {
            ForEach(sessions) { session in
                SessionRowView(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
    }

    private func deleteSessions(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let session = sessions[index]
                do {
                    try await sessionRepository.delete(session)
                    Log.persistence.info("Deleted session: \(session.planName)")
                } catch {
                    Log.persistence.error("Failed to delete session: \(error)")
                }
            }
            // Reload after deletion
            await loadSessions()
        }
    }

    private func loadSessions() async {
        isLoading = true
        do {
            sessions = try await sessionRepository.fetchRecent(limit: 50)
        } catch {
            Log.persistence.error("Failed to load sessions: \(error)")
            sessions = []
        }
        isLoading = false
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Status indicator with workout type icon
            Image(systemName: session.isWalkingWorkout ? "figure.walk" : "figure.run")
                .font(.title3)
                .foregroundStyle(session.isCompleted ? Color.green : Color.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(session.planName)
                    .font(.headline)

                HStack(spacing: DesignTokens.Spacing.md) {
                    Label(session.durationFormatted, systemImage: "clock")
                    Label(session.distanceFormatted, systemImage: "location")

                    // Show steps for walking workouts, HR for running
                    if session.isWalkingWorkout && session.totalSteps > 0 {
                        Label(session.stepsFormatted, systemImage: "shoeprints.fill")
                    } else if session.avgHeartRate > 0 {
                        Label("\(session.avgHeartRate) lpm", systemImage: "heart.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Score badge
            VStack {
                Text("\(Int(session.score))")
                    .font(.title2.bold())
                    .foregroundStyle(scoreColor)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var scoreColor: Color {
        switch session.score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Header
                    sessionHeader

                    // Summary Cards
                    summaryCards

                    // Intervals Chart
                    if !session.intervals.isEmpty {
                        intervalsSection
                    }

                    // Stats Grid
                    statsGrid
                }
                .padding()
            }
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.3), lineWidth: 12)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: session.score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(session.score))")
                        .font(.title.bold())
                    Text("puntos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(session.planName)
                .font(.title2.bold())

            Text(session.startDate.formatted(date: .complete, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Status badge
            HStack {
                Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(session.isCompleted ? "Completado" : "Parcial")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(session.isCompleted ? .green : .orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((session.isCompleted ? Color.green : Color.orange).opacity(0.15))
            .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
    }

    private var scoreColor: Color {
        switch session.score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private var summaryCards: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            SummaryCard(
                title: "Duración",
                value: session.durationFormatted,
                icon: "clock.fill",
                color: .blue
            )

            SummaryCard(
                title: "Distancia",
                value: session.distanceFormatted,
                icon: "location.fill",
                color: .green
            )

            SummaryCard(
                title: "Ritmo",
                value: session.avgPaceFormatted,
                icon: "speedometer",
                color: .orange
            )
        }
    }

    private var intervalsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Intervalos")
                .font(.headline)

            // Simple bar chart for intervals
            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(session.intervals) { interval in
                    IntervalBar(interval: interval, maxDuration: maxIntervalDuration)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }

    private var maxIntervalDuration: TimeInterval {
        session.intervals.map(\.duration).max() ?? 1
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Estadísticas")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignTokens.Spacing.md) {
                StatItem(label: "FC Media", value: "\(session.avgHeartRate) lpm", icon: "heart.fill")
                StatItem(label: "FC Máxima", value: "\(session.maxHeartRate) lpm", icon: "heart.circle")
                StatItem(label: "Tiempo en Zona", value: formatTimeInZone(session.timeInZone), icon: "target")
                StatItem(label: "% en Zona", value: String(format: "%.0f%%", session.timeInZonePercentage), icon: "percent")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }

    private func formatTimeInZone(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }
}

// MARK: - Interval Bar
struct IntervalBar: View {
    let interval: IntervalRecord
    let maxDuration: TimeInterval

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Phase indicator
            Text(interval.phase.shortName)
                .font(.caption.weight(.medium))
                .foregroundStyle(interval.phase.color)
                .frame(width: 50, alignment: .leading)

            // Bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(interval.phase.color.opacity(0.7))
                    .frame(width: geo.size.width * CGFloat(interval.duration / maxDuration))
            }
            .frame(height: 20)

            // Duration
            Text(formatDuration(interval.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
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
