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

// MARK: - Placeholder Views
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("IntervalPro")
                    .font(.largeTitle.bold())

                Text("Entrenamiento por intervalos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Inicio")
        }
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
