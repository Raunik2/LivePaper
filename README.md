# LivePaper

**Live video wallpaper engine for macOS Tahoe.** Play any video as your desktop wallpaper with a Mond-style clock overlay, automatic screensaver/lock screen integration, and battery-aware power management.

![macOS](https://img.shields.io/badge/macOS-Tahoe%2016.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Install

Paste this in Terminal — it downloads, builds, installs, and launches LivePaper:

```bash
curl -sL https://raw.githubusercontent.com/Raunik2/LivePaper/main/install.sh | bash
```

That's it. No Gatekeeper warnings, no "Move to Bin" dialog, no manual setup.

> **Requires:** macOS Tahoe (16.0+) and Xcode Command Line Tools (the script will prompt you to install them if missing).

### Alternative: Clone & Build

```bash
git clone https://github.com/Raunik2/LivePaper.git && cd LivePaper && bash build3.sh
```

## Features

- **Live Video Wallpaper** — Any MP4/MOV/M4V as desktop background with seamless looping
- **Mond Clock Widget** — Elegant Anurati-font clock overlay with 3 styles (Classic, Classic + Seconds, Small)
- **Lock Screen & Screensaver** — Video automatically overlays the lock screen and system screensaver
- **System Aerial Injection** — Registers your video as a native macOS aerial in System Settings
- **Video Library** — Browse and switch between videos from `~/Movies/LivePaper/`
- **Multi-Monitor** — Works across all connected displays
- **Battery Optimized** — Auto-lowers resolution on battery; optional full pause on battery
- **Smart Pausing** — Auto-pauses when desktop is occluded or display sleeps
- **Menu Bar + CLI** — Control from the status bar or via pipe commands
- **GUI Dashboard** — Modern SwiftUI control panel

## Usage

Double-click LivePaper.app — the dashboard opens and the wallpaper starts.

### Dashboard Controls

- **Now Playing** — Play/pause, volume slider
- **Video Library** — Click any thumbnail to switch wallpapers
- **Choose Video File** — Pick any video; it's copied to the library automatically
- **Settings** — Lock screen overlay, Mond clock style, pause on battery

### Getting Videos

1. Download animated wallpapers from [moewalls.com](https://moewalls.com/)
2. Drop `.mp4`/`.mov` files into `~/Movies/LivePaper/`
3. Or use **Choose Video File** in the dashboard

### CLI Control

```bash
echo "pause"   > /tmp/livepaper.pipe
echo "resume"  > /tmp/livepaper.pipe
echo "change /path/to/video.mp4" > /tmp/livepaper.pipe
echo "volume 50"    > /tmp/livepaper.pipe
echo "dashboard"    > /tmp/livepaper.pipe
echo "clock on"     > /tmp/livepaper.pipe
echo "clock 0"      > /tmp/livepaper.pipe   # 0=Classic, 1=+Seconds, 2=Small
echo "quit"         > /tmp/livepaper.pipe
```

Launch with a specific video:
```bash
open /Applications/LivePaper.app --args --video ~/Movies/LivePaper/my-wallpaper.mp4
```

## How It Works

| Layer | Detail |
|---|---|
| **Video Playback** | `AVQueuePlayer` + `AVPlayerLooper` with hardware-accelerated `AVPlayerLayer` |
| **Desktop Level** | Wallpaper windows at `desktopWindow + 1` — above real wallpaper, below everything else |
| **Aerial Injection** | Writes to `~/Library/Application Support/com.apple.wallpaper/aerials/` to register as native aerial |
| **Lock Screen** | Elevates windows above `CGShieldingWindowLevel` when screen locks |
| **Battery Mode** | Caps decode at 1080p + 5 Mbps on battery; optional full pause |
| **Occlusion Pause** | Monitors `NSWindow.didChangeOcclusionStateNotification` to stop decode when hidden |

## Project Structure

```
Sources/
├── main.swift              # Entry point + macOS version gate
├── Config.swift            # UserDefaults settings + font registration
├── LivePaperApp.swift      # NSApplicationDelegate — core lifecycle
├── VideoPlayer.swift       # AVQueuePlayer view + wallpaper window
├── Screensaver.swift       # Screensaver & lock screen controller
├── WindowPersistence.swift # Timer to keep wallpaper windows alive
├── BatteryMonitor.swift    # AC/battery detection via IOKit
├── MondClock.swift         # Mond clock widget + overlay window
├── AerialsInjector.swift   # System aerial wallpaper injection
├── VideoLibrary.swift      # ~/Movies/LivePaper/ management
├── Dashboard.swift         # SwiftUI dashboard
├── StatusBar.swift         # Menu bar controller
└── CommandListener.swift   # Named pipe CLI listener
build3.sh                   # Build, sign & install script
install.sh                  # One-command installer (curl-friendly)
```

## License

MIT License — Copyright (c) 2026 Raunak Gupta
