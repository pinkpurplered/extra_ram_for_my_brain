import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = LoopAudioRecorder()
    @State private var exportMinutes: Double = 5

    var body: some View {
        VStack(spacing: 24) {
            Text(recorder.isRecording ? "Recording…" : "Stopped")
                .font(.title)
                .foregroundColor(recorder.isRecording ? .green : .red)

            HStack(spacing: 16) {
                Button(action: {
                    recorder.isRecording ? recorder.stop() : recorder.start()
                }) {
                    Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Save last \(Int(exportMinutes)) min")
                Slider(value: $exportMinutes, in: 1...60, step: 1)
            }

            Button(action: {
                Task {
                    do {
                        let url = try await recorder.saveLast(minutes: Int(exportMinutes))
                        print("Saved clip at: \(url)")
                    } catch {
                        print("Export error: \(error)")
                    }
                }
            }) {
                Text("Save last \(Int(exportMinutes)) min")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let lastSaved = recorder.lastSavedURL {
                Text("Last saved: \(lastSaved.lastPathComponent)")
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            recorder.prepare()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


