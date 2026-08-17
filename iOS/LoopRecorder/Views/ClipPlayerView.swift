import SwiftUI

struct ClipPlayerView: View {
    @ObservedObject var player: ClipPlaybackController
    let clip: SavedClip
    var compact: Bool = false
    var onDelete: (() -> Void)?
    var onRename: (() -> Void)?

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            if !compact {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clip.displayTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text(clip.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    clipActions
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await player.load(clip.url)
                        player.togglePlayPause()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                        if player.isLoading && player.currentClipURL == clip.url {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: playButtonIcon)
                                .font(.system(size: compact ? 16 : 18, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(player.isLoading && player.currentClipURL == clip.url)

                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { scrubberValue },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    .tint(accent)
                    .disabled(player.duration <= 0)

                    HStack {
                        Text(formatTime(scrubberValue))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            if compact {
                HStack(spacing: 8) {
                    Text(clip.fileName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    clipActions
                }
            }
        }
        .task(id: clip.url) {
            // Compact preview sits on the recording screen — loading here would fight the mic session.
            guard !compact else { return }
            if player.currentClipURL != clip.url {
                await player.load(clip.url)
            }
        }
    }

    private var playButtonIcon: String {
        guard player.currentClipURL == clip.url, player.isPlaying else {
            return "play.fill"
        }
        return "pause.fill"
    }

    private var scrubberValue: TimeInterval {
        player.currentClipURL == clip.url ? player.currentTime : 0
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let totalSeconds = Int(time.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var clipActions: some View {
        HStack(spacing: compact ? 4 : 6) {
            if let onRename {
                actionButton(systemName: "pencil", label: "Rename recording", action: onRename)
            }
            if let onDelete {
                deleteButton(action: onDelete)
            }
        }
    }

    private func actionButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: compact ? 13 : 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(compact ? 6 : 8)
                .background(Circle().fill(Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.system(size: compact ? 13 : 15, weight: .medium))
                .foregroundStyle(.red.opacity(0.85))
                .padding(compact ? 6 : 8)
                .background(Circle().fill(Color.red.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete recording")
    }
}
