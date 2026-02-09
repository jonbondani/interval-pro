import SwiftUI

// MARK: - Pace Display (Walking Workout - Main Metric)
struct WalkingPaceDisplay: View {
    let currentPace: Double
    let formattedPace: String
    let targetZone: HeartRateZone?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundStyle(.green)

                Text(formattedPace)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("/km")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Pace zone indicator based on target
            if let zone = targetZone, let targetPace = zone.targetPace {
                PaceZoneBar(
                    currentPace: currentPace,
                    targetPace: targetPace,
                    tolerance: zone.paceTolerance
                )
                .frame(height: 18)
                .padding(.horizontal, DesignTokens.Spacing.md)

                Text(paceStatus(zone: zone, targetPace: targetPace))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(paceColor(zone: zone, targetPace: targetPace))
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
    }

    private func paceStatus(zone: HeartRateZone, targetPace: Double) -> String {
        guard currentPace > 0 else { return "Sin datos" }

        let diff = currentPace - targetPace
        if abs(diff) <= zone.paceTolerance {
            return "Ritmo perfecto"
        } else if diff > 0 {
            return "Acelera un poco"
        } else {
            return "Reduce el ritmo"
        }
    }

    private func paceColor(zone: HeartRateZone, targetPace: Double) -> Color {
        guard currentPace > 0 else { return .secondary }

        let diff = currentPace - targetPace
        if abs(diff) <= zone.paceTolerance {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Metrics Row Walking (Pace, Distance, Steps)
struct WalkingMetricsRow: View {
    let formattedPace: String
    let formattedDistance: String
    let formattedSteps: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            MetricCard(
                value: formattedPace,
                label: "PACE",
                icon: "speedometer"
            )

            MetricCard(
                value: formattedDistance,
                label: "DIST",
                icon: "location"
            )

            MetricCard(
                value: formattedSteps,
                label: "PASOS",
                icon: "figure.walk"
            )
        }
    }
}

// MARK: - Pace Zone Bar (for Walking)
struct PaceZoneBar: View {
    let currentPace: Double  // sec/km
    let targetPace: Double   // sec/km
    let tolerance: Double    // sec tolerance

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                // Target zone highlight
                let minPos = pacePosition(targetPace + tolerance, in: geo.size.width)
                let maxPos = pacePosition(targetPace - tolerance, in: geo.size.width)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.3))
                    .frame(width: abs(maxPos - minPos))
                    .offset(x: min(minPos, maxPos))

                // Current pace indicator
                let pacePos = pacePosition(currentPace, in: geo.size.width)
                Circle()
                    .fill(isInZone ? .green : .orange)
                    .frame(width: 12, height: 12)
                    .offset(x: pacePos - 6)
                    .animation(.spring(response: 0.3), value: currentPace)
            }
        }
        .frame(height: 16)
    }

    private var isInZone: Bool {
        abs(currentPace - targetPace) <= tolerance
    }

    private func pacePosition(_ pace: Double, in width: CGFloat) -> CGFloat {
        // Map pace range 420-600 sec/km (7:00-10:00/km) to width
        // Lower pace = faster = further right
        let minPace: CGFloat = 420   // 7:00/km (fast walking)
        let maxPace: CGFloat = 660   // 11:00/km (slow walking)
        let normalized = 1.0 - (CGFloat(pace) - minPace) / (maxPace - minPace)
        return max(0, min(width, normalized * width))
    }
}

// MARK: - Metronome Control Sheet (Long press on metronome button)
struct MetronomeControlSheet: View {
    @Binding var metronomeBPM: Int
    @Binding var metronomeVolume: Float
    let onBPMChange: (Int) -> Void
    let onVolumeChange: (Float) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "metronome.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Metrónomo")
                    .font(.headline)
            }
            .padding(.top)

            // BPM Control
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Tempo")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: DesignTokens.Spacing.lg) {
                    // -5 button
                    Button {
                        let newBPM = max(100, metronomeBPM - 5)
                        metronomeBPM = newBPM
                        onBPMChange(newBPM)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                    }

                    // BPM display
                    VStack(spacing: 0) {
                        Text("\(metronomeBPM)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 100)

                    // +5 button
                    Button {
                        let newBPM = min(220, metronomeBPM + 5)
                        metronomeBPM = newBPM
                        onBPMChange(newBPM)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                    }
                }
            }

            Divider()
                .padding(.horizontal)

            // Volume Control
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Volumen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)

                    Slider(value: $metronomeVolume, in: 0...1) { editing in
                        if !editing {
                            onVolumeChange(metronomeVolume)
                        }
                    }
                    .tint(.blue)

                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Text("\(Int(metronomeVolume * 100))%")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)

            // Note
            Text("No afecta al volumen de la música")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, DesignTokens.Spacing.xs)

            Spacer()
        }
    }
}

// MARK: - Voice Control Sheet (Long press on voice button)
struct VoiceControlSheet: View {
    @Binding var voiceVolume: Float
    let onVolumeChange: (Float) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Notificaciones de Voz")
                    .font(.headline)
            }
            .padding(.top)

            // Volume Control
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Volumen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)

                    Slider(value: $voiceVolume, in: 0...1) { editing in
                        if !editing {
                            onVolumeChange(voiceVolume)
                        }
                    }
                    .tint(.green)

                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Text("\(Int(voiceVolume * 100))%")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal)

            // Note
            Text("No afecta al volumen de la música")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, DesignTokens.Spacing.xs)

            Spacer()
        }
    }
}
