## LoopRecorder (iOS)

Continuous background voice recording with a rolling 5-hour buffer, plus a one-tap way to save the last N minutes forever.

### Features
- Rolling recording via segmented files (default 60s segments)
- Retains only the most recent 5 hours; automatically deletes older segments
- Works in background (enable Background Modes: Audio)
- Save last N minutes (default 5) to a single `.m4a` file in a persistent `Saved` folder
- Simple SwiftUI UI to start/stop and save

### Requirements
- Xcode 15+
- iOS 15+

### Setup
1) Create a new SwiftUI App in Xcode (iOS App → SwiftUI, include tests optional)
2) Drag the contents of `iOS/LoopRecorder` into your project (keep folder references)
   - Add folders: `Audio`, `Models`, the Swift files, and `Config/InfoPlistAdditions.plist`

3) Info.plist
   - Add microphone usage string:
     - Key: `NSMicrophoneUsageDescription`
     - Value: "This app records audio to maintain a rolling buffer and allow saving clips."

4) Background Modes
   - In your target → Signing & Capabilities → "+ Capability" → Background Modes
   - Check: `Audio, AirPlay, and Picture in Picture`

5) App audio session
   - The provided code configures `AVAudioSession` for recording and keeps it active; recording will continue in background.

6) Build & Run
   - Launch on a real device (microphone not available in most simulators)
   - Grant mic permission when prompted
   - Tap "Start Recording"; the status shows active
   - Tap "Save last 5 min" to export a clip; find it under the app’s Documents/Saved folder

### Notes
- Retention window is set to 5 hours by default; adjust `retentionWindow` in `LoopAudioRecorder`.
- Segment length defaults to 60s; adjust `segmentDurationSeconds`.
- Exporter stitches the necessary recent segments into a single file using `AVMutableComposition`.


