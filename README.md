# extra_ram_for_my_brain

Personal tools for capturing and keeping audio when you need a rolling buffer of recent sound — not a full archive of everything.

## Projects

| Path | Description |
|------|-------------|
| [`iOS/LoopRecorder`](iOS/LoopRecorder/) | iPhone app — continuous background recording with a 1-hour rolling buffer and one-tap clip export |

## Loop Recorder (iOS)

A minimal SwiftUI app that:

- Records in the background using 60-second segments
- Keeps only the **last 1 hour** (older segments are deleted automatically)
- Lets you **save the last N minutes** (1–60) as a permanent `.m4a` file

**Best on a real iPhone** — the simulator does not provide a microphone.

### Quick start

```bash
open iOS/LoopRecorder/LoopRecorder.xcodeproj
```

1. In Xcode, select your **Signing Team** (Signing & Capabilities).
2. Plug in your iPhone, enable **Developer Mode** on the device if prompted.
3. Choose your phone as the run destination and press **Run** (⌘R).
4. On first install: **Settings → General → VPN & Device Management** → trust your developer certificate.
5. Grant **microphone** permission when you start recording.

Full setup, architecture, and configuration: **[iOS/LoopRecorder/README.md](iOS/LoopRecorder/README.md)**

## Requirements

- macOS with **Xcode 15+**
- iPhone running **iOS 15+** (for Loop Recorder)
- Apple ID (free Personal Team is enough for device testing)

## Repository structure

```
extra_ram_for_my_brain/
├── README.md                 # This file
├── iOS/
│   └── LoopRecorder/         # Loop Recorder Xcode project + source
│       ├── LoopRecorder.xcodeproj
│       ├── Audio/              # Recording, retention, export
│       ├── Models/
│       ├── Config/             # Info.plist
│       └── README.md           # Detailed app documentation
```

## License

Private / personal use unless otherwise noted.
