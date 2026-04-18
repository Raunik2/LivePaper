# LivePaper

**Live video wallpapers for macOS Tahoe.**

![macOS](https://img.shields.io/badge/macOS-Tahoe%2016.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Install

```bash
curl -sL https://raw.githubusercontent.com/Raunik2/LivePaper/main/install.sh | bash
```

That's it — one command. No Homebrew needed, no Gatekeeper warnings.

> **Requires:** macOS Tahoe 16.0+ and Xcode Command Line Tools (the installer handles everything else).

## What You Get

- **Any video as your wallpaper** — MP4, MOV, M4V with seamless looping
- **Lock screen & screensaver** — your video plays natively on the lock screen
- **YouTube download** — paste a URL in the dashboard to import wallpapers
- **Mond clock overlay** — elegant clock widget on your desktop
- **Battery smart** — lowers quality on battery, optionally pauses completely
- **Multi-monitor** — works across all displays
- **Menu bar control** — play, pause, change video from the status bar

## Getting Wallpapers

1. **YouTube** — paste any URL in the dashboard
2. **[moewalls.com](https://moewalls.com)** — click "Browse More Live Wallpapers" in the dashboard
3. **Local files** — drop videos into `~/Movies/LivePaper/`

## CLI Control

```bash
echo "pause"   > /tmp/livepaper.pipe
echo "resume"  > /tmp/livepaper.pipe
echo "change /path/to/video.mp4" > /tmp/livepaper.pipe
echo "volume 50"  > /tmp/livepaper.pipe
echo "quit"       > /tmp/livepaper.pipe
```

## Build from Source

```bash
git clone https://github.com/Raunik2/LivePaper.git && cd LivePaper && bash build3.sh
```

## License

MIT — Copyright (c) 2026 Raunak Gupta
