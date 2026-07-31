import SwiftUI

struct RenameClipSheet: View {
    let clip: SavedClip
    let onSave: (SavedClip) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?

    init(clip: SavedClip, onSave: @escaping (SavedClip) -> Void) {
        self.clip = clip
        self.onSave = onSave
        _name = State(initialValue: clip.editableName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                } footer: {
                    Text("The .m4a extension is added automatically.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Rename recording")
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
            let renamed = try clip.rename(to: name)
            onSave(renamed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
