import SwiftUI

struct SavedClipsSheet: View {
    @ObservedObject var player: ClipPlaybackController
    @Environment(\.dismiss) private var dismiss

    @State private var folders: [ClipFolder] = []
    @State private var clips: [SavedClip] = []
    @State private var currentFolder: ClipFolder?
    @State private var selectedClip: SavedClip?
    @State private var loadError: String?
    @State private var clipPendingDeletion: SavedClip?
    @State private var clipPendingRename: SavedClip?
    @State private var clipPendingMove: SavedClip?
    @State private var folderPendingDeletion: ClipFolder?
    @State private var folderPendingRename: ClipFolder?
    @State private var showCreateFolder = false

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    emptyState(
                        title: "Couldn't load recordings",
                        systemImage: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if isEmpty {
                    emptyState(
                        title: emptyTitle,
                        systemImage: currentFolder == nil ? "waveform" : "folder",
                        message: emptyMessage
                    )
                } else {
                    List {
                        if currentFolder == nil, !folders.isEmpty {
                            Section("Folders") {
                                ForEach(folders) { folder in
                                    Button {
                                        openFolder(folder)
                                    } label: {
                                        FolderRow(folder: folder)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            folderPendingRename = folder
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            folderPendingDeletion = folder
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        if !clips.isEmpty {
                            Section(currentFolder == nil ? "Recordings" : "Recordings") {
                                ForEach(clips) { clip in
                                    Button {
                                        select(clip)
                                    } label: {
                                        SavedClipRow(
                                            clip: clip,
                                            isSelected: selectedClip == clip
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            clipPendingMove = clip
                                        } label: {
                                            Label("Move to folder", systemImage: "folder")
                                        }
                                        Button {
                                            clipPendingRename = clip
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            clipPendingDeletion = clip
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    if let index = offsets.first {
                                        clipPendingDeletion = clips[index]
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(currentFolder?.name ?? "Audio Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentFolder != nil {
                        Button {
                            closeFolder()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Folders")
                            }
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("New folder")
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
        .confirmationDialog(
            "Delete this folder?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { folder in
            Button("Delete", role: .destructive) {
                deleteFolder(folder)
            }
        } message: { folder in
            Text(folder.name)
        }
        .sheet(item: $clipPendingRename) { clip in
            RenameClipSheet(clip: clip) { renamed in
                applyRename(from: clip, to: renamed)
            }
        }
        .sheet(item: $folderPendingRename) { folder in
            RenameFolderSheet(folder: folder) { renamed in
                applyFolderRename(from: folder, to: renamed)
            }
        }
        .sheet(item: $clipPendingMove) { clip in
            MoveToFolderSheet(
                clip: clip,
                currentFolder: currentFolder,
                folders: folders
            ) { moved in
                applyMove(from: clip, to: moved)
            }
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderSheet { folder in
                folders.append(folder)
                folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                loadError = nil
            }
        }
    }

    private var isEmpty: Bool {
        clips.isEmpty && (currentFolder != nil || folders.isEmpty)
    }

    private var emptyTitle: String {
        if currentFolder != nil {
            return "No recordings"
        }
        return "No saved recordings"
    }

    private var emptyMessage: String {
        if currentFolder != nil {
            return "Recordings moved here will appear in this folder."
        }
        return "Saved clips will appear here after you export from the recorder. Create folders to organize them."
    }

    private func reload() {
        do {
            if currentFolder == nil {
                folders = try ClipFolder.loadAll()
            }
            clips = try SavedClip.loadAll(in: currentFolder?.url)
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

    private func openFolder(_ folder: ClipFolder) {
        currentFolder = folder
        selectedClip = nil
        player.stop()
        reload()
    }

    private func closeFolder() {
        currentFolder = nil
        selectedClip = nil
        player.stop()
        reload()
    }

    private func select(_ clip: SavedClip) {
        selectedClip = clip
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

    private func deleteFolder(_ folder: ClipFolder) {
        folderPendingDeletion = nil
        do {
            try folder.delete()
            folders.removeAll { $0 == folder }
            if currentFolder == folder {
                closeFolder()
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
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

    private func applyFolderRename(from oldFolder: ClipFolder, to newFolder: ClipFolder) {
        folderPendingRename = nil
        if let index = folders.firstIndex(of: oldFolder) {
            folders[index] = newFolder
            folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        if currentFolder == oldFolder {
            currentFolder = newFolder
        }
        loadError = nil
    }

    private func applyMove(from oldClip: SavedClip, to newClip: SavedClip) {
        clipPendingMove = nil
        let wasPlaying = player.currentClipURL == oldClip.url && player.isPlaying

        clips.removeAll { $0 == oldClip }
        if selectedClip == oldClip {
            selectedClip = clips.first
        }
        loadError = nil

        if player.currentClipURL == oldClip.url {
            player.stop()
            if wasPlaying, let selectedClip {
                Task {
                    await player.load(selectedClip.url)
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

private struct FolderRow: View {
    let folder: ClipFolder

    @State private var clipCount = 0

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "folder.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                Text(clipCount == 1 ? "1 recording" : "\(clipCount) recordings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task(id: folder.url) {
            clipCount = (try? folder.clipCount()) ?? 0
        }
    }
}

private struct SavedClipRow: View {
    let clip: SavedClip
    let isSelected: Bool

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.15) : Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform")
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

private struct RenameFolderSheet: View {
    let folder: ClipFolder
    let onSave: (ClipFolder) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    init(folder: ClipFolder, onSave: @escaping (ClipFolder) -> Void) {
        self.folder = folder
        self.onSave = onSave
        _name = State(initialValue: folder.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Folder name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Rename folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        do {
            let renamed = try folder.rename(to: name)
            onSave(renamed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
