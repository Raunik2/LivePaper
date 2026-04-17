// LivePaper – Configuration & Font Registration

import AppKit
import CoreText

// MARK: - Font Registration

func registerBundledFonts() {
    if let resourcePath = Bundle.main.resourceURL {
        let fontURL = resourcePath.appendingPathComponent("Anurati-Regular.otf")
        if FileManager.default.fileExists(atPath: fontURL.path) {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
    let userFont = NSString(string: "~/Library/Fonts/Anurati-Regular.otf").expandingTildeInPath
    if FileManager.default.fileExists(atPath: userFont) {
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: userFont) as CFURL, .process, nil)
    }
}

// MARK: - Configuration

class LivePaperConfig {
    static let shared = LivePaperConfig()
    private let d = UserDefaults.standard
    private let p = "LP3."

    var wallpaperVideoPath: String? {
        get { d.string(forKey: p + "wallpaperVideo") }
        set { d.set(newValue, forKey: p + "wallpaperVideo") }
    }
    var clockEnabled: Bool {
        get { d.object(forKey: p + "clockOn") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "clockOn") }
    }
    var clockStyle: Int {
        get { d.integer(forKey: p + "clockStyle") }
        set { d.set(newValue, forKey: p + "clockStyle") }
    }
    var screensaverEnabled: Bool {
        get { d.object(forKey: p + "ssOn") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "ssOn") }
    }
    var volume: Float {
        get {
            let key = p + "volume"
            if d.object(forKey: key) == nil { return 0.5 }
            return d.float(forKey: key)
        }
        set { d.set(newValue, forKey: p + "volume") }
    }
    var aerialsAssetID: String? {
        get { d.string(forKey: p + "aerialsAssetID") }
        set { d.set(newValue, forKey: p + "aerialsAssetID") }
    }
    var lockScreenEnabled: Bool {
        get { d.object(forKey: p + "lockScreenOn") as? Bool ?? true }
        set { d.set(newValue, forKey: p + "lockScreenOn") }
    }
    var pauseOnBattery: Bool {
        get { d.object(forKey: p + "pauseOnBattery") as? Bool ?? false }
        set { d.set(newValue, forKey: p + "pauseOnBattery") }
    }
}
