import SwiftUI

// MARK: - Music Widget
struct MusicWidget: View {
    @ObservedObject var viewModel: TrainingViewModel
    let openURL: OpenURLAction

    var body: some View {
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
