import SwiftUI

struct MoveToFolderSheet: View {
    let clip: SavedClip
    let currentFolder: ClipFolder?
    let folders: [ClipFolder]
    let onMove: (SavedClip) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                if currentFolder != nil {
                    Button {
                        move(to: nil)
                    } label: {
                        Label("No folder", systemImage: "tray")
                    }
                }

                ForEach(folders) { folder in
                    if folder != currentFolder {
                        Button {
                            move(to: folder)
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Move to folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func move(to folder: ClipFolder?) {
        do {
            let moved = try clip.move(to: folder)
            onMove(moved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
