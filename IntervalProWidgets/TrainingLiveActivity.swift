import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Lock Screen / Notification Banner View

struct TrainingLockScreenView: View {
    let state: TrainingActivityAttributes.ContentState

    var phaseColor: Color { state.phaseLabel == "Trabajo" ? .red : .blue }

    var body: some View {
        HStack(spacing: 16) {
            // Phase badge
            VStack(spacing: 4) {
                Text(state.phaseEmoji)
                    .font(.title2)
                Text(state.phaseLabel.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 52)

            Divider()

            // Live countdown timer
            VStack(alignment: .leading, spacing: 2) {
                Text(timerInterval: Date.now...state.phaseEndDate, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(phaseColor)
                    .monospacedDigit()
                Text("Serie \(state.seriesNumber) de \(state.totalSeries)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Metrics
            VStack(alignment: .trailing, spacing: 6) {
                Label("\(state.targetSPM) SPM", systemImage: "metronome.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Label(state.currentPaceFormatted + " /km", systemImage: "figure.run")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Live Activity Widget

struct IntervalProLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            TrainingLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phaseLabel, systemImage: context.attributes.planName.isEmpty ? "figure.run" : "figure.run")
                        .font(.caption.bold())
                        .foregroundStyle(context.state.phaseLabel == "Trabajo" ? .red : .blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.phaseEndDate, countsDown: true)
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(context.state.phaseLabel == "Trabajo" ? .red : .blue)
                        .frame(width: 60)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Serie \(context.state.seriesNumber)/\(context.state.totalSeries)")
                        Spacer()
                        Text("\(context.state.targetSPM) SPM")
                        Spacer()
                        Text(context.state.currentPaceFormatted + " /km")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text(context.state.phaseEmoji)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.phaseEndDate, countsDown: true)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(context.state.phaseLabel == "Trabajo" ? .red : .blue)
                    .frame(width: 40)
            } minimal: {
                Text(context.state.phaseEmoji)
            }
        }
    }
}
