# Recall Audio

iPhone app that records in the background and keeps **only the last hour**. Save the last 1–60 minutes anytime as a `.m4a` file.

**Needs a real iPhone** — the simulator has no microphone. Xcode 15+, iOS 15+, free Apple ID for signing.

## Setup

```bash
open LoopRecorder.xcodeproj
```

1. **Signing & Capabilities** → pick your Team.
2. Connect your iPhone, enable **Developer Mode** if asked.
3. Run (⌘R). First install: **Settings → General → VPN & Device Management** → Trust.
4. Allow **microphone** when you tap record.

## Use it

1. Tap the mic to start recording (works in the background).
2. Slide to pick how many minutes to save (1–60), then tap **Save**.
3. Open **Saved Clips** to play or manage exports.

Older than 1 hour is deleted automatically. Saved clips stay until you remove them.

## Find your files

**Files → On My iPhone → Recall Audio → extraramformybrain**

## Tweaks

In `Audio/LoopAudioRecorder.swift`:

- `retentionWindow` — how long to keep audio (default: 1 hour)
- `segmentDurationSeconds` — segment length (default: 60s)

## Problems?

| Issue | Fix |
|-------|-----|
| Won't open after install | Trust developer in **VPN & Device Management** |
| No mic | Use a physical iPhone |
| Nothing to save yet | Record for at least ~60 seconds first |
| Signing errors | Pick a valid Team in Xcode |

## Support

If this app is useful to you, [buy me a coffee](https://buymeacoffee.com/pinkredpurple).
