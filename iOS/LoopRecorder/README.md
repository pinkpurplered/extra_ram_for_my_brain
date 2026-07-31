# Loop Recorder

Continuous background voice recording with a **1-hour rolling buffer**, plus a one-tap way to save the last N minutes as a permanent clip.

![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## What it does

Loop Recorder is designed for situations where you want recent audio on tap without storing hours of recordings forever.

| Behavior | Detail |
|----------|--------|
| **Rolling buffer** | Keeps the most recent **1 hour** of audio in segmented files |
| **Segment size** | **60 seconds** per file (`.m4a`, AAC) |
| **Background** | Recording continues when the app is backgrounded (audio background mode) |
| **Save clip** | Export the last **1–60 minutes** into `Documents/Saved/` as one `.m4a` |
| **Storage** | Segments older than 1 hour are deleted automatically |

Saved clips are **separate files** in `Saved/` and are not removed by the rolling buffer.

## Screenshots / UI

- Minimal SwiftUI interface: status pill, central record button, save card with duration slider
- Coral accent for recording state and primary actions

## Requirements

- **Xcode 15+**
- **iOS 15+**
- **Physical iPhone** recommended (simulator has no real microphone)
- Apple ID for code signing (Personal Team works)

## Installation (Mac + iPhone)

### 1. Open the project

```bash
open iOS/LoopRecorder/LoopRecorder.xcodeproj
```

Or from the repo root:

```bash
open LoopRecorder.xcodeproj
```

when your shell is already in `iOS/LoopRecorder/`.

### 2. Xcode components

If build fails with *“iOS platform not installed”*:

**Xcode → Settings → Components** → download **iOS Simulator** (and platform if listed).

Device builds on a physical phone do not require the simulator runtime, but Xcode must be fully set up.

### 3. Code signing

1. Select the **LoopRecorder** target.
2. **Signing & Capabilities** → **Team** → choose your Apple ID / Personal Team.
3. Bundle identifier defaults to `com.extraram.LoopRecorder` (change if needed).

### 4. iPhone setup

1. Connect the iPhone via USB or Wi-Fi debugging.
2. Unlock the phone and **Trust This Computer** if prompted.
3. Enable **Developer Mode**: **Settings → Privacy & Security → Developer Mode** → On (restart required).
4. Build and run from Xcode (⌘R) with your phone selected as the destination.

### 5. Trust the developer (first install only)

**Settings → General → VPN & Device Management** → your Apple ID → **Trust**.

### 6. Microphone permission

When you tap record, allow microphone access. Without it, recording cannot start.

## Usage

1. **Tap the mic** — starts rolling recording (status shows *Recording*).
2. **Tap stop** — ends recording (buffer segments remain on disk until retention runs).
3. **Adjust duration** — slider under *Save clip* (1–60 minutes).
4. **Save** — exports a single `.m4a` to the app’s `Saved` folder.

While recording, a subtle pulse animation indicates active capture.

## Where files live

On device, inside the app sandbox:

| Path | Contents |
|------|----------|
| `Documents/Segments/` | Rolling buffer segment files (`segment_*.m4a`) |
| `Documents/Saved/` | Exported clips (`saved_*m_*.m4a`) |

Access during development via Xcode **Devices and Simulators** → select device → **Loop Recorder** → container download, or a future in-app share feature.

## Configuration

Edit defaults in `Audio/LoopAudioRecorder.swift`:

```swift
let segmentDurationSeconds: TimeInterval = 60      // length of each segment
let retentionWindow: TimeInterval = 1 * 60 * 60    // rolling buffer (1 hour)
```

| Setting | Default | Notes |
|---------|---------|--------|
| `retentionWindow` | 1 hour | Older segments are deleted after each rotation |
| `segmentDurationSeconds` | 60 s | Smaller = more files; larger = coarser export edges |
| Export range | 1–60 min | UI slider in `ContentView.swift` |

## Architecture

```
LoopRecorderApp.swift          App entry
ContentView.swift            SwiftUI UI
Audio/
  LoopAudioRecorder.swift    Session, segments, timer rotation, save API
  SegmentRetentionManager.swift   Deletes segments past retention window
  AudioCompositionExporter.swift  Stitches segments → single .m4a (AVMutableComposition)
Models/
  RecordingSegment.swift       Segment metadata (url, start, duration)
Config/
  Info.plist                   Mic usage string, background audio mode
```

### Recording flow

1. `AVAudioSession` is configured for `.playAndRecord` and kept active.
2. `AVAudioRecorder` writes one segment file; a timer rotates to a new file every 60s.
3. On rotation, `SegmentRetentionManager` removes segment files older than the retention window.
4. Export selects segments overlapping the requested time range and merges them with `AVAssetExportSession`.

### Background recording

`UIBackgroundModes` includes `audio` in `Info.plist`. iOS allows continued audio capture while backgrounded when the audio session is active. Segment rotation uses a main-run-loop timer — adequate for normal use; very long background sessions may need additional hardening in future versions.

## Build from the command line

Simulator (smoke test — no mic):

```bash
cd iOS/LoopRecorder
xcodebuild -project LoopRecorder.xcodeproj \
  -scheme LoopRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Device (replace with your device id from `xcrun xctrace list devices`):

```bash
xcodebuild -project LoopRecorder.xcodeproj \
  -scheme LoopRecorder \
  -destination 'id=YOUR_DEVICE_UDID' \
  -allowProvisioningUpdates \
  build
```

Install to a connected device:

```bash
xcrun devicectl device install app --device YOUR_DEVICE_UDID \
  ~/Library/Developer/Xcode/DerivedData/LoopRecorder-*/Build/Products/Debug-iphoneos/LoopRecorder.app
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| *Developer Mode disabled* | Enable in **Settings → Privacy & Security → Developer Mode** |
| App won’t open after install | Trust developer in **VPN & Device Management** |
| No microphone on simulator | Use a physical iPhone |
| *No audio yet* when saving | Record for at least part of one segment (~60s) before exporting |
| Signing errors | Select a valid **Team** in Xcode; sign in via **Settings → Apple Accounts** |
| Missing iOS platform | **Xcode → Settings → Components** |

## Legacy note

`Config/InfoPlistAdditions.plist` was used for manual Xcode project setup. The Xcode project now uses **`Config/Info.plist`** as the canonical Info.plist.

## Roadmap ideas

- Share sheet for saved clips
- List of saved recordings in the app
- Optional auto-start recording on launch
- Files app integration (`UIFileSharingEnabled`)
