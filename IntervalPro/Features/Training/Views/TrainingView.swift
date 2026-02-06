import SwiftUI

/// Active training session view
/// Shows real-time HR, timer, phase, and metrics
struct TrainingView: View {
    @StateObject private var viewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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

                    // Music widget
                    if viewModel.isMusicConnected {
                        musicWidget
                            .padding(.horizontal)
                            .padding(.top, DesignTokens.Spacing.sm)
                    }

                    Spacer()

                    // Main content
                    VStack(spacing: DesignTokens.Spacing.md) {
                        phaseIndicator
                        timerDisplay
                        cadenceDisplay       // Cadence with zone tracking
                        heartRateDisplay     // FC - just display
                        metricsRow
                        paceComparisonSection
                        seriesProgress
                    }
                    .padding(.horizontal)

                    Spacer()

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

            // Data source indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(dataSourceColor)
                    .frame(width: 8, height: 8)

                Text(dataSourceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Elapsed time
            Text(viewModel.totalElapsedTime.formattedHoursMinutesSeconds)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            // Audio controls
            HStack(spacing: DesignTokens.Spacing.md) {
                // Voice toggle
                Button {
                    viewModel.toggleVoice()
                } label: {
                    Image(systemName: viewModel.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isVoiceEnabled ? .green : .secondary)
                }
                .accessibleTapTarget()

                // Metronome toggle
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

    // MARK: - Music Widget
    private var musicWidget: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Album art or music icon
            Group {
                if let track = viewModel.nowPlayingTrack,
                   let artworkData = track.artworkData,
                   let image = Image(data: artworkData) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: viewModel.activeService.iconName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                if let track = viewModel.nowPlayingTrack {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Sin reproducción")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Playback controls
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    Task { await viewModel.skipToPreviousTrack() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .accessibleTapTarget()

                Button {
                    Task { await viewModel.togglePlayPause() }
                } label: {
                    Image(systemName: viewModel.musicPlaybackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .accessibleTapTarget()

                Button {
                    Task { await viewModel.skipToNextTrack() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .accessibleTapTarget()

                // Open music app button
                Button {
                    if let url = viewModel.musicAppURL {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibleTapTarget()
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color(.secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
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

    // MARK: - Cadence Display (Zone Tracking)
    private var cadenceDisplay: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "figure.run")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("\(viewModel.currentCadence)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("SPM")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Zone indicator - cadence vs target
            CadenceZoneBar(
                currentCadence: viewModel.currentCadence,
                targetZone: viewModel.targetZone,
                status: viewModel.zoneStatus
            )
            .frame(height: 18)
            .padding(.horizontal, DesignTokens.Spacing.md)

            // Zone status text
            Text(viewModel.zoneStatus.instruction)
                .font(.caption.weight(.medium))
                .foregroundStyle(viewModel.zoneStatus.color)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }

    // MARK: - Heart Rate Display (FC - only with real data, not simulation)
    @ViewBuilder
    private var heartRateDisplay: some View {
        if viewModel.isGarminConnected {
            // Show real HR from Garmin
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, value: viewModel.currentHeartRate)

                Text("\(viewModel.currentHeartRate)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("lpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("FC")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
        }
        // When not connected to Garmin, don't show HR widget (no real HR data)
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

    // MARK: - Pace Comparison Section
    private var paceComparisonSection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Best pace to beat
            VStack(spacing: 2) {
                Text("RÉCORD")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                if viewModel.bestPace > 0 {
                    Text(viewModel.formattedBestPace)
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                } else {
                    Text("--:--")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 24)

            // Current vs best indicator
            VStack(spacing: 2) {
                Text("VS RÉCORD")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    if viewModel.bestPace > 0 && viewModel.currentPace > 0 {
                        Image(systemName: paceComparisonIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(paceComparisonColor)

                        Text(viewModel.formattedPaceDelta)
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(paceComparisonColor)
                    } else {
                        Text("--:--")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
                .frame(height: 24)

            // Status indicator
            VStack(spacing: 2) {
                Text("ESTADO")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(paceStatusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(paceComparisonColor)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
    }

    private var paceComparisonIcon: String {
        if viewModel.isFasterThanBest {
            return "arrow.up.circle.fill"
        } else if viewModel.isSlowerThanBest {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle.fill"
        }
    }

    private var paceComparisonColor: Color {
        if viewModel.isFasterThanBest {
            return .green
        } else if viewModel.isSlowerThanBest {
            return .red
        } else {
            return .orange
        }
    }

    private var dataSourceText: String {
        if viewModel.isGarminConnected {
            return "Garmin"
        } else if viewModel.isSimulationMode {
            return "Simulado"
        } else {
            return "iPhone"
        }
    }

    private var dataSourceColor: Color {
        if viewModel.isGarminConnected {
            return .green
        } else if viewModel.isSimulationMode {
            return .orange
        } else {
            return .blue  // iPhone sensors
        }
    }

    private var paceStatusText: String {
        guard viewModel.bestPace > 0 && viewModel.currentPace > 0 else {
            return "Sin datos"
        }

        if viewModel.isFasterThanBest {
            return "Mejor"
        } else if viewModel.isSlowerThanBest {
            return "Por debajo"
        } else {
            return "En ritmo"
        }
    }

    // MARK: - Series Progress
    private var seriesProgress: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Show block info for progressive workouts
            if viewModel.totalBlocks > 1 {
                Text("Serie \(viewModel.currentSeries)/\(viewModel.totalSeries) · Bloque \(viewModel.currentBlock)/\(viewModel.totalBlocks)")
                    .font(.headline)

                // Show target cadence for current block
                if let zone = viewModel.targetZone {
                    Text("Cadencia: \(zone.targetCadence) SPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Serie \(viewModel.currentSeries) de \(viewModel.totalSeries)")
                    .font(.headline)
            }

            if viewModel.totalSeries > 0 {
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

    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            if viewModel.timerState == .stopped && viewModel.currentPhase == .idle {
                // Start button
                Button {
                    Task {
                        try? await viewModel.startWorkout()
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
                            try? await viewModel.resumeWorkout()
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

// MARK: - Cadence Zone Bar
struct CadenceZoneBar: View {
    let currentCadence: Int
    let targetZone: HeartRateZone?  // Actually cadence zone
    let status: ZoneStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                // Zone indicators
                if let zone = targetZone {
                    let minPos = cadencePosition(zone.minCadence, in: geo.size.width)
                    let maxPos = cadencePosition(zone.maxCadence, in: geo.size.width)

                    // Target zone highlight
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: maxPos - minPos)
                        .offset(x: minPos)

                    // Current cadence indicator
                    let cadencePos = cadencePosition(currentCadence, in: geo.size.width)
                    Circle()
                        .fill(status.color)
                        .frame(width: 12, height: 12)
                        .offset(x: cadencePos - 6)
                        .animation(.spring(response: 0.3), value: currentCadence)
                }
            }
        }
        .frame(height: 16)
    }

    private func cadencePosition(_ cadence: Int, in width: CGFloat) -> CGFloat {
        // Map cadence range 130-200 SPM to width
        let minCadence: CGFloat = 130
        let maxCadence: CGFloat = 200
        let normalized = (CGFloat(cadence) - minCadence) / (maxCadence - minCadence)
        return max(0, min(width, normalized * width))
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }
}

// MARK: - Previews
#Preview("Work Phase - Faster") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(
            phase: .work,
            hr: 155,        // FC
            cadence: 172,   // SPM - en zona
            pace: 310,      // 5:10/km - faster than record
            bestPace: 330   // 5:30/km
        )
    )
}

#Preview("Work Phase - Slower") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(
            phase: .work,
            hr: 165,
            cadence: 168,
            pace: 360,      // 6:00/km - slower than record
            bestPace: 330   // 5:30/km
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Rest Phase") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(phase: .rest, hr: 130, cadence: 148)
    )
    .preferredColorScheme(.dark)
}

#Preview("Idle") {
    TrainingView(
        plan: .intermediate,
        viewModel: TrainingViewModel.preview(phase: .idle, hr: 0, cadence: 0)
    )
}

// MARK: - Image+Data Extension
#if canImport(UIKit)
import UIKit

extension Image {
    /// Creates an Image from raw data (PNG, JPEG, etc.)
    /// Returns nil if the data cannot be converted to an image
    init?(data: Data) {
        guard let uiImage = UIImage(data: data) else { return nil }
        self.init(uiImage: uiImage)
    }
}
#endif
