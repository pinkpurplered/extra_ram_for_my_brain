import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = LoopAudioRecorder()
    @State private var exportMinutes: Double = 5
    @State private var statusMessage: String?
    @State private var isExporting = false
    @State private var pulse = false

    private let accent = Color(red: 0.95, green: 0.35, blue: 0.28)

    var body: some View {
        ZStack {
            background

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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
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
        VStack(spacing: 10) {
            Text("Loop Recorder")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(recorder.isRecording ? accent : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(recorder.isRecording && pulse ? 1.2 : 1)
                    .animation(
                        recorder.isRecording
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
                            .scaleEffect(pulse ? 1.08 : 1)
                            .opacity(pulse ? 0.4 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
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
        }
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Save clip", systemImage: "square.and.arrow.down")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

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

            if let lastSaved = recorder.lastSavedURL {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(lastSaved.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
