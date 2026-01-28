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
    @State private var showTraining = false

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
            .fullScreenCover(isPresented: $showTraining) {
                if let plan = selectedPlan {
                    TrainingView(plan: plan)
                }
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
                selectedPlan = TrainingPlan.intermediate
                showTraining = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Entrenamiento Recomendado")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("4x3min Intermedio")
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
                    showTraining = true
                }
            }
        }
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
    var body: some View {
        NavigationStack {
            Text("Perfil")
                .navigationTitle("Perfil")
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Bienvenido a IntervalPro")
                .font(.title.bold())

            Text("Entrena por intervalos con precisión basada en tu frecuencia cardíaca")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                appState.completeOnboarding()
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
