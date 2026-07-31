import SwiftUI

struct SavedClipsSheet: View {
    @ObservedObject var player: ClipPlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var clips: [SavedClip] = []
    @State private var selectedClip: SavedClip?
    @State private var loadError: String?
    @State private var clipPendingDeletion: SavedClip?
    @State private var clipPendingRename: SavedClip?

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    emptyState(
                        title: "Couldn't load recordings",
                        systemImage: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if clips.isEmpty {
                    emptyState(
                        title: "No saved recordings",
                        systemImage: "waveform",
                        message: "Saved clips will appear here after you export from the recorder."
                    )
                } else {
                    List {
                        ForEach(clips) { clip in
                            Button {
                                select(clip)
                            } label: {
                                SavedClipRow(
                                    clip: clip,
                                    isSelected: selectedClip == clip,
                                    isPlaying: player.currentClipURL == clip.url && player.isPlaying
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                clipPendingDeletion = clips[index]
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let selectedClip {
                    VStack(spacing: 0) {
                        Divider()
                        ClipPlayerView(
                            player: player,
                            clip: selectedClip,
                            onDelete: { clipPendingDeletion = selectedClip },
                            onRename: { clipPendingRename = selectedClip }
                        )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { reload() }
        .onDisappear { player.stop() }
        .confirmationDialog(
            "Delete this recording?",
            isPresented: Binding(
                get: { clipPendingDeletion != nil },
                set: { if !$0 { clipPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: clipPendingDeletion
        ) { clip in
            Button("Delete", role: .destructive) {
                delete(clip)
            }
        } message: { clip in
            Text(clip.displayTitle)
        }
        .sheet(item: $clipPendingRename) { clip in
            RenameClipSheet(clip: clip) { renamed in
                applyRename(from: clip, to: renamed)
            }
        }
    }

    private func reload() {
        do {
            clips = try SavedClip.loadAll()
            loadError = nil
            if let selectedClip, !clips.contains(selectedClip) {
                self.selectedClip = clips.first
            } else if selectedClip == nil {
                selectedClip = clips.first
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func select(_ clip: SavedClip) {
        if selectedClip == clip {
            player.togglePlayPause()
        } else {
            selectedClip = clip
            Task {
                await player.load(clip.url)
                player.togglePlayPause()
            }
        }
    }

    private func delete(_ clip: SavedClip) {
        clipPendingDeletion = nil
        if player.currentClipURL == clip.url {
            player.stop()
        }
        do {
            try clip.delete()
            clips.removeAll { $0 == clip }
            if selectedClip == clip {
                selectedClip = clips.first
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            reload()
        }
    }

    private func applyRename(from oldClip: SavedClip, to newClip: SavedClip) {
        clipPendingRename = nil
        let wasPlaying = player.currentClipURL == oldClip.url && player.isPlaying

        if let index = clips.firstIndex(of: oldClip) {
            clips[index] = newClip
            clips.sort { $0.createdAt > $1.createdAt }
        }
        if selectedClip == oldClip {
            selectedClip = newClip
        }
        loadError = nil

        if player.currentClipURL == oldClip.url {
            Task {
                await player.load(newClip.url)
                if wasPlaying {
                    player.togglePlayPause()
                }
            }
        }
    }

    private func emptyState(title: String, systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SavedClipRow: View {
    let clip: SavedClip
    let isSelected: Bool
    let isPlaying: Bool

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.15) : Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.displayTitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Text(clip.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(accent)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
