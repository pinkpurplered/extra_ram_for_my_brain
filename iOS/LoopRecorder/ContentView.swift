import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = LoopAudioRecorder()
    @StateObject private var clipPlayer = ClipPlaybackController()
    @State private var exportMinutes: Double = 5
    @State private var statusMessage: String?
    @State private var isExporting = false
    @State private var pulse = false
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var showSavedClips = false
    @State private var previewClip: SavedClip?
    @State private var showDeletePreviewConfirmation = false
    @State private var showRenamePreviewSheet = false

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)
    private static let buyMeACoffeeURL = URL(string: "https://buymeacoffee.com/pinkredpurple")!

    private var shouldPulse: Bool {
        recorder.isRecording && pulse && !isLowPowerModeEnabled
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 8)

                        Spacer(minLength: 24)

                        recordControl

                        Spacer(minLength: 32)

                        saveCard

                        if let feedback = combinedFeedback {
                            Text(feedback.text)
                                .font(.subheadline)
                                .foregroundStyle(feedback.isSuccess ? .green : .red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 16)

                        Link(destination: Self.buyMeACoffeeURL) {
                            Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: recorder.isRecording)
        .animation(.easeInOut(duration: 0.2), value: statusMessage)
        .onAppear {
            recorder.prepare()
            if recorder.isRecording {
                pulse = true
            }
        }
        .onChange(of: recorder.isRecording) { isRecording in
            pulse = isRecording
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .sheet(isPresented: $showSavedClips) {
            SavedClipsSheet(player: clipPlayer)
        }
        .onChange(of: recorder.lastSavedURL) { url in
            guard let url else { return }
            previewClip = SavedClip(url: url)
        }
    }

    private var background: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    accent.opacity(recorder.isRecording ? 0.12 : 0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Text("Recall Audio")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(recorder.isRecording ? accent : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(shouldPulse ? 1.2 : 1)
                        .animation(
                            shouldPulse
                                ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                                : .default,
                            value: pulse
                        )

                    Text(recorder.isRecording ? "Recording" : "Idle")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(recorder.isRecording ? accent : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                )

                if recorder.isRecording {
                    Text("1 hour rolling buffer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                showSavedClips = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Audio Preview")
        }
    }

    private var recordControl: some View {
        VStack(spacing: 20) {
            Button {
                statusMessage = nil
                recorder.isRecording ? recorder.stop() : recorder.start()
            } label: {
                ZStack {
                    if recorder.isRecording {
                        Circle()
                            .stroke(accent.opacity(0.35), lineWidth: 2)
                            .frame(width: 112, height: 112)
                            .scaleEffect(shouldPulse ? 1.08 : 1)
                            .opacity(shouldPulse ? 0.4 : 0.8)
                            .animation(
                                shouldPulse
                                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                    : .default,
                                value: pulse
                            )
                    }

                    Circle()
                        .fill(
                            recorder.isRecording
                                ? accent.opacity(0.15)
                                : Color(.secondarySystemBackground)
                        )
                        .frame(width: 96, height: 96)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(recorder.isRecording ? accent : .primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

            Text(recorder.isRecording ? "Tap to stop" : "Tap to record")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Only record with permission from everyone present.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Save clip", systemImage: "square.and.arrow.down")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Saved to \(SavedClipDirectory.displayPath)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(exportMinutes)) min")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Slider(value: $exportMinutes, in: 1...60, step: 1)
                .tint(accent)

            Button {
                Task {
                    isExporting = true
                    statusMessage = nil
                    defer { isExporting = false }
                    do {
                        let url = try await recorder.saveLast(minutes: Int(exportMinutes))
                        statusMessage = "Saved · \(url.lastPathComponent)"
                    } catch {
                        statusMessage = exportErrorMessage(error)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "waveform")
                    }
                    Text(isExporting ? "Saving…" : "Save last \(Int(exportMinutes)) minutes")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .disabled(!recorder.isRecording || isExporting)

            if !recorder.isRecording {
                Text("Start recording to enable saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let previewClip {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Ready to preview")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    ClipPlayerView(
                        player: clipPlayer,
                        clip: previewClip,
                        compact: true,
                        onDelete: { showDeletePreviewConfirmation = true },
                        onRename: { showRenamePreviewSheet = true }
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .confirmationDialog(
            "Delete this recording?",
            isPresented: $showDeletePreviewConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePreviewClip()
            }
        } message: {
            if let previewClip {
                Text(previewClip.displayTitle)
            }
        }
        .sheet(isPresented: $showRenamePreviewSheet) {
            if let previewClip {
                RenameClipSheet(clip: previewClip) { renamed in
                    applyPreviewRename(from: previewClip, to: renamed)
                }
            }
        }
    }

    private struct Feedback {
        let text: String
        let isSuccess: Bool
    }

    private var combinedFeedback: Feedback? {
        if let lastError = recorder.lastError {
            return Feedback(text: lastError, isSuccess: false)
        }
        if let statusMessage {
            return Feedback(text: statusMessage, isSuccess: statusMessage.hasPrefix("Saved"))
        }
        return nil
    }

    private func exportErrorMessage(_ error: Error) -> String {
        if let exportError = error as? ExportError {
            switch exportError {
            case .noSegments:
                return "No audio yet — record a little longer first."
            case .compositionFailed, .exportFailed:
                return "Export failed. Try again."
            }
        }
        return error.localizedDescription
    }

    private func deletePreviewClip() {
        guard let previewClip else { return }
        if clipPlayer.currentClipURL == previewClip.url {
            clipPlayer.stop()
        }
        try? previewClip.delete()
        self.previewClip = nil
        statusMessage = nil
    }

    private func applyPreviewRename(from oldClip: SavedClip, to newClip: SavedClip) {
        let wasPlaying = clipPlayer.currentClipURL == oldClip.url && clipPlayer.isPlaying
        previewClip = newClip
        statusMessage = "Saved · \(newClip.fileName)"

        if clipPlayer.currentClipURL == oldClip.url {
            Task {
                await clipPlayer.load(newClip.url)
                if wasPlaying {
                    clipPlayer.togglePlayPause()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
