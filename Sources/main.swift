// LivePaper v3.0 – Entry Point

import AppKit

let app = NSApplication.shared

// Require macOS Tahoe or later — Sequoia (15.x) has critical incompatibilities
let osVer = ProcessInfo.processInfo.operatingSystemVersion
if osVer.majorVersion <= 15 {
    let alert = NSAlert()
    alert.messageText = "LivePaper Requires macOS Tahoe or Later"
    alert.informativeText = "You are running macOS \(osVer.majorVersion).\(osVer.minorVersion). LivePaper requires macOS Tahoe (16.0+) to work correctly. Please update your macOS."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Quit")
    alert.runModal()
    exit(1)
}

var videoPath: String? = nil
let clArgs = CommandLine.arguments
if clArgs.count > 1 {
    for i in 1..<clArgs.count {
        if (clArgs[i] == "--video" || clArgs[i] == "-v"), i + 1 < clArgs.count {
            videoPath = clArgs[i + 1]
        } else if clArgs[i] == "--help" || clArgs[i] == "-h" {
            print("LivePaper v3.0 — Just double-click the app! Or: LivePaper --video <path>")
            exit(0)
        } else if !clArgs[i].hasPrefix("-") && videoPath == nil {
            videoPath = clArgs[i]
        }
    }
}

if videoPath == nil { videoPath = LivePaperConfig.shared.wallpaperVideoPath }

var videoURL: URL? = nil
if let p = videoPath {
    let expanded = (p as NSString).expandingTildeInPath
    if FileManager.default.fileExists(atPath: expanded) {
        videoURL = URL(fileURLWithPath: expanded)
    }
}

let delegate = LivePaperApp(videoURL: videoURL)
app.delegate = delegate
app.run()
