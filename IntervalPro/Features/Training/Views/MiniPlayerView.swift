import SwiftUI

/// Compact music player bar for use during workouts
/// Non-intrusive, thumb-friendly controls
struct MiniPlayerView: View {
    @ObservedObject var musicController: UnifiedMusicController

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main player bar
            HStack(spacing: DesignTokens.Spacing.md) {
                // Service icon and track info
                trackInfo

                Spacer()

                // Playback controls
                playbackControls
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }

            // Expanded view with volume and more controls
            if isExpanded {
                expandedControls
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    // MARK: - Track Info

    @ViewBuilder
    private var trackInfo: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Service icon
            Image(systemName: musicController.activeService.iconName)
                .font(.title3)
                .foregroundStyle(serviceColor)
                .frame(width: 24)

            if let track = musicController.nowPlaying {
                // Track artwork (if available)
                if let artworkData = track.artworkData,
                   let image = UIImage(data: artworkData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }

                // Track title and artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                // No track playing
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sin reproducción")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(musicController.activeService == .none ?
                         "Conecta un servicio" :
                         musicController.activeService.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var serviceColor: Color {
        switch musicController.activeService {
        case .appleMusic: return .pink
        case .spotify: return .green
        case .none: return .gray
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Previous track
            Button {
                Task { await musicController.skipToPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .accessibleTapTarget()
            .disabled(!musicController.isConnected)

            // Play/Pause
            Button {
                Task { await musicController.togglePlayPause() }
            } label: {
                Image(systemName: musicController.playbackState.isPlaying ?
                      "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .accessibleTapTarget()
            .disabled(!musicController.isConnected)

            // Next track
            Button {
                Task { await musicController.skipToNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .accessibleTapTarget()
            .disabled(!musicController.isConnected)
        }
    }

    // MARK: - Expanded Controls

    private var expandedControls: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Divider()

            // Volume slider
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(musicController.config.musicVolume) },
                        set: { Task { await musicController.setVolume(Float($0)) } }
                    ),
                    in: 0...1
                )
                .tint(serviceColor)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Service selector
            if musicController.activeService == .none {
                serviceSelector
            }

            // Connection status
            if let error = musicController.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background(Color(.secondarySystemBackground))
    }

    private var serviceSelector: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button {
                Task { try? await musicController.authorizeAppleMusic() }
            } label: {
                Label("Apple Music", systemImage: "music.note")
                    .font(.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.pink.opacity(0.2))
                    .clipShape(Capsule())
            }

            Button {
                Task { try? await musicController.authorizeSpotify() }
            } label: {
                Label("Spotify", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Full Screen Player Sheet

struct FullPlayerSheet: View {
    @ObservedObject var musicController: UnifiedMusicController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Artwork
                artworkView
                    .frame(maxWidth: 300, maxHeight: 300)

                // Track info
                if let track = musicController.nowPlaying {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text(track.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(track.artist)
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        if let album = track.album {
                            Text(album)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text("Sin reproducción")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Playback controls
                HStack(spacing: DesignTokens.Spacing.xl) {
                    Button {
                        Task { await musicController.skipToPrevious() }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    .disabled(!musicController.isConnected)

                    Button {
                        Task { await musicController.togglePlayPause() }
                    } label: {
                        Image(systemName: musicController.playbackState.isPlaying ?
                              "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                    }
                    .disabled(!musicController.isConnected)

                    Button {
                        Task { await musicController.skipToNext() }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .disabled(!musicController.isConnected)
                }
                .foregroundStyle(.primary)

                // Volume
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "speaker.fill")
                    Slider(
                        value: Binding(
                            get: { Double(musicController.config.musicVolume) },
                            set: { Task { await musicController.setVolume(Float($0)) } }
                        )
                    )
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .foregroundStyle(.secondary)

                // Service indicator
                Label(
                    musicController.activeService.displayName,
                    systemImage: musicController.activeService.iconName
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .padding()
            .navigationTitle("Música")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let track = musicController.nowPlaying,
           let artworkData = track.artworkData,
           let image = UIImage(data: artworkData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Music Settings View

struct MusicSettingsView: View {
    @ObservedObject var musicController: UnifiedMusicController
    @State private var showSpotifyLogin = false

    var body: some View {
        Form {
            Section("Servicio de música") {
                Picker("Preferido", selection: $musicController.config.preferredService) {
                    ForEach(MusicServiceType.allCases) { service in
                        Label(service.displayName, systemImage: service.iconName)
                            .tag(service)
                    }
                }

                HStack {
                    Text("Estado")
                    Spacer()
                    if musicController.isConnected {
                        Label("Conectado", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Desconectado", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)

                if musicController.activeService == .spotify {
                    Button("Reconectar Spotify") {
                        showSpotifyLogin = true
                    }
                }
            }

            Section("Audio") {
                VStack(alignment: .leading) {
                    Text("Volumen de música")
                    Slider(
                        value: Binding(
                            get: { Double(musicController.config.musicVolume) },
                            set: { musicController.config.musicVolume = Float($0) }
                        )
                    )
                }

                Toggle("Reducir durante anuncios", isOn: $musicController.config.duckDuringAnnouncements)

                if musicController.config.duckDuringAnnouncements {
                    VStack(alignment: .leading) {
                        Text("Nivel de reducción")
                        Slider(
                            value: Binding(
                                get: { Double(musicController.config.duckingLevel) },
                                set: { musicController.config.duckingLevel = Float($0) }
                            ),
                            in: 0.1...0.5
                        )
                    }
                }
            }

            Section {
                NavigationLink("Acerca de la integración de música") {
                    MusicIntegrationInfoView()
                }
            }
        }
        .navigationTitle("Música")
    }
}

struct MusicIntegrationInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Integración de Música")
                    .font(.title2.bold())

                Text("IntervalPro puede controlar tu música mientras entrenas, sin interrumpir la reproducción.")

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Apple Music")
                                .font(.headline)
                            Text("Requiere suscripción activa")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "music.note")
                            .foregroundStyle(.pink)
                    }

                    Label {
                        VStack(alignment: .leading) {
                            Text("Spotify")
                                .font(.headline)
                            Text("Requiere la app de Spotify instalada")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                    }
                }

                Text("El metrónomo y los anuncios de voz se reproducirán sobre tu música sin pausarla.")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#Preview("Mini Player - Playing") {
    VStack {
        Spacer()
        MiniPlayerView(musicController: .previewPlaying)
            .padding()
    }
}

#Preview("Mini Player - No Service") {
    VStack {
        Spacer()
        MiniPlayerView(musicController: .previewNoService)
            .padding()
    }
}

#Preview("Full Player") {
    FullPlayerSheet(musicController: .previewPlaying)
}

#Preview("Settings") {
    NavigationStack {
        MusicSettingsView(musicController: .previewPlaying)
    }
}

// MARK: - Preview Helpers

extension UnifiedMusicController {
    @MainActor
    static var previewPlaying: UnifiedMusicController {
        let controller = UnifiedMusicController(
            appleMusicController: .shared,
            spotifyController: .shared,
            config: .default
        )
        // Note: Can't easily set state for preview without mocking
        return controller
    }

    @MainActor
    static var previewNoService: UnifiedMusicController {
        let controller = UnifiedMusicController(
            appleMusicController: .shared,
            spotifyController: .shared,
            config: MusicControllerConfig(
                preferredService: .none,
                musicVolume: 0.7,
                duckDuringAnnouncements: true,
                duckingLevel: 0.3
            )
        )
        return controller
    }
}
