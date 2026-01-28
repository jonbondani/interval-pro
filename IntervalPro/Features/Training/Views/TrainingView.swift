import SwiftUI

/// Active training session view
/// Shows real-time HR, timer, phase, and metrics
struct TrainingView: View {
    @StateObject private var viewModel: TrainingViewModel
    @StateObject private var musicController = UnifiedMusicController.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showMusicPlayer = false

    let plan: TrainingPlan

    init(plan: TrainingPlan, viewModel: TrainingViewModel? = nil) {
        self.plan = plan
        self._viewModel = StateObject(wrappedValue: viewModel ?? TrainingViewModel())
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on phase
                phaseBackground

                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    Spacer()

                    // Main content
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        phaseIndicator
                        timerDisplay
                        heartRateDisplay
                        metricsRow
                        seriesProgress
                        bestSessionComparison
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Mini music player (when connected)
                    if musicController.isConnected || musicController.nowPlaying != nil {
                        MiniPlayerView(musicController: musicController)
                            .padding(.horizontal)
                            .padding(.bottom, DesignTokens.Spacing.sm)
                            .onTapGesture {
                                showMusicPlayer = true
                            }
                    }

                    // Control buttons
                    controlButtons
                        .padding(.bottom, geometry.safeAreaInsets.bottom + DesignTokens.Spacing.lg)
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .task {
            await viewModel.configure(with: plan)
            await musicController.detectActiveService()
        }
        .onChange(of: viewModel.timerState) { _, newState in
            if newState == .stopped && viewModel.currentPhase == .complete {
                // Navigate to summary
            }
        }
        .sheet(isPresented: $showMusicPlayer) {
            FullPlayerSheet(musicController: musicController)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Phase Background
    private var phaseBackground: some View {
        LinearGradient(
            colors: [
                viewModel.currentPhase.color.opacity(0.3),
                viewModel.currentPhase.color.opacity(0.1),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentPhase)
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                Task {
                    await viewModel.stopWorkout()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .accessibleTapTarget()

            Spacer()

            // Elapsed time
            Text(viewModel.totalElapsedTime.formattedHoursMinutesSeconds)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            // Audio controls
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    viewModel.toggleMetronome()
                } label: {
                    Image(systemName: viewModel.isMetronomeEnabled ? "metronome.fill" : "metronome")
                        .font(.title2)
                        .foregroundStyle(viewModel.isMetronomeEnabled ? .blue : .secondary)
                }
                .accessibleTapTarget()
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }

    // MARK: - Phase Indicator
    private var phaseIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: viewModel.currentPhase.icon)
                .font(.title2)

            Text(viewModel.currentPhase.shortName)
                .font(DesignTokens.Typography.phaseIndicator)
        }
        .foregroundStyle(viewModel.currentPhase.color)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(viewModel.currentPhase.color.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text(viewModel.phaseRemainingTime.formattedMinutesSeconds)
                .font(DesignTokens.Typography.timerDisplay)
                .monospacedDigit()
                .contentTransition(.numericText())

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(viewModel.currentPhase.color)
                        .frame(width: geo.size.width * viewModel.phaseProgress)
                        .animation(.linear(duration: 0.1), value: viewModel.phaseProgress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
    }

    // MARK: - Heart Rate Display
    private var heartRateDisplay: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, value: viewModel.currentHeartRate)

                Text("\(viewModel.currentHeartRate)")
                    .font(DesignTokens.Typography.hrDisplay)
                    .contentTransition(.numericText())

                Text("BPM")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Zone indicator
            HRZoneBar(
                currentHR: viewModel.currentHeartRate,
                targetZone: viewModel.targetZone,
                status: viewModel.zoneStatus
            )
            .padding(.horizontal, DesignTokens.Spacing.lg)

            // Zone status text
            Text(viewModel.zoneStatus.instruction)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(viewModel.zoneStatus.color)
        }
        .cardStyle()
    }

    // MARK: - Metrics Row
    private var metricsRow: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            MetricCard(
                value: viewModel.formattedPace,
                label: "PACE",
                icon: "figure.run"
            )

            MetricCard(
                value: viewModel.formattedDistance,
                label: "DIST",
                icon: "location"
            )
        }
    }

    // MARK: - Series Progress
    private var seriesProgress: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text("Serie \(viewModel.currentSeries) de \(viewModel.totalSeries)")
                .font(.headline)

            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(1...viewModel.totalSeries, id: \.self) { series in
                    Circle()
                        .fill(seriesColor(for: series))
                        .frame(width: 12, height: 12)
                        .overlay {
                            if series == viewModel.currentSeries {
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                            }
                        }
                }
            }
        }
    }

    private func seriesColor(for series: Int) -> Color {
        if series < viewModel.currentSeries {
            return .green
        } else if series == viewModel.currentSeries {
            return viewModel.currentPhase.color
        } else {
            return .gray.opacity(0.3)
        }
    }

    // MARK: - Best Session Comparison
    @ViewBuilder
    private var bestSessionComparison: some View {
        if viewModel.bestSession != nil {
            HStack {
                Image(systemName: viewModel.isAheadOfBest ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(viewModel.isAheadOfBest ? .green : .red)

                Text(viewModel.isAheadOfBest ? "Adelante" : "Atrás")
                    .font(.subheadline.weight(.medium))

                Text("vs mejor sesión")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
    }

    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            if viewModel.timerState == .stopped && viewModel.currentPhase == .idle {
                // Start button
                Button {
                    Task {
                        try await viewModel.startWorkout()
                    }
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 60)
                        .background(.green)
                        .clipShape(Capsule())
                }
            } else {
                // Pause/Resume button
                Button {
                    Task {
                        if viewModel.timerState == .running {
                            await viewModel.pauseWorkout()
                        } else {
                            try await viewModel.resumeWorkout()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.timerState == .running ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(viewModel.timerState == .running ? .orange : .green)
                        .clipShape(Circle())
                }

                // Stop button
                Button {
                    Task {
                        await viewModel.stopWorkout()
                        dismiss()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }
}

// MARK: - HR Zone Bar
struct HRZoneBar: View {
    let currentHR: Int
    let targetZone: HeartRateZone?
    let status: ZoneStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))

                // Zone indicators
                if let zone = targetZone {
                    let minPos = hrPosition(zone.minBPM, in: geo.size.width)
                    let maxPos = hrPosition(zone.maxBPM, in: geo.size.width)

                    // Target zone highlight
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: maxPos - minPos)
                        .offset(x: minPos)

                    // Current HR indicator
                    let hrPos = hrPosition(currentHR, in: geo.size.width)
                    Circle()
                        .fill(status.color)
                        .frame(width: 16, height: 16)
                        .offset(x: hrPos - 8)
                        .animation(.spring(response: 0.3), value: currentHR)
                }
            }
        }
        .frame(height: 24)
    }

    private func hrPosition(_ hr: Int, in width: CGFloat) -> CGFloat {
        // Map HR range 100-200 to width
        let minHR: CGFloat = 100
        let maxHR: CGFloat = 200
        let normalized = (CGFloat(hr) - minHR) / (maxHR - minHR)
        return normalized * width
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(DesignTokens.Typography.paceDisplay)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }
}

// MARK: - Previews
#Preview("Work Phase") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(phase: .work, hr: 168)
    )
}

#Preview("Rest Phase") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(phase: .rest, hr: 145)
    )
    .preferredColorScheme(.dark)
}

#Preview("Idle") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(phase: .idle, hr: 0)
    )
}
