// LivePaper – Aerials Injection (Backdrop-style)
// Injects a video into Apple's wallpaper aerials system so it appears as a native
// aerial screensaver/wallpaper in System Settings with its own "LivePaper" section.

import AppKit
import AVFoundation

class AerialsInjector {
    private let aerialsBase = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials").expandingTildeInPath
    private let videosDir = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/videos").expandingTildeInPath
    private let thumbsDir = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails").expandingTildeInPath
    private let entriesPath = NSString(string: "~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json").expandingTildeInPath
    private let storePath = NSString(string: "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist").expandingTildeInPath

    private let categoryID   = "LP000000-0000-4000-8000-000000000001"
    private let subcategoryID = "LP000000-0000-4000-8000-000000000002"

    func inject(videoURL: URL, name: String? = nil, forceRestart: Bool = true) -> Bool {
        let uuid = LivePaperConfig.shared.aerialsAssetID ?? UUID().uuidString.uppercased()
        let videoName = name ?? videoURL.deletingPathExtension().lastPathComponent
        let fm = FileManager.default

        let destPath = (videosDir as NSString).appendingPathComponent("\(uuid).mov")
        let destURL = URL(fileURLWithPath: destPath)
        let srcSize = (try? fm.attributesOfItem(atPath: videoURL.path)[.size] as? Int) ?? -1
        let dstSize = (try? fm.attributesOfItem(atPath: destPath)[.size] as? Int) ?? -2
        let videoChanged = srcSize != dstSize
        if videoChanged {
            do {
                try fm.createDirectory(atPath: videosDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destPath) { try fm.removeItem(atPath: destPath) }
                try fm.copyItem(at: videoURL, to: destURL)
            } catch {
                NSLog("LivePaper: Failed to copy video: \(error)")
                return false
            }
        }

        let thumbPath = (thumbsDir as NSString).appendingPathComponent("\(uuid).png")
        if videoChanged || !fm.fileExists(atPath: thumbPath) {
            try? fm.createDirectory(atPath: thumbsDir, withIntermediateDirectories: true)
            generateThumbnail(from: videoURL, to: thumbPath)
        }

        guard updateEntriesJSON(assetID: uuid, videoName: videoName) else {
            NSLog("LivePaper: Failed to update entries.json")
            return false
        }

        guard updateWallpaperStore(assetID: uuid) else {
            NSLog("LivePaper: Failed to update wallpaper store")
            return false
        }

        LivePaperConfig.shared.aerialsAssetID = uuid

        if forceRestart || videoChanged {
            NSLog("LivePaper: Aerials injection — restarting WallpaperAgent (videoChanged=%d, forceRestart=%d)",
                  videoChanged ? 1 : 0, forceRestart ? 1 : 0)
            restartWallpaperAgent()
            verifyAgentRestart()
        } else {
            NSLog("LivePaper: Aerials injection — skipping agent restart (no changes)")
            if !isWallpaperAgentRunning() {
                NSLog("LivePaper: WallpaperAgent not running — restarting")
                restartWallpaperAgent()
                verifyAgentRestart()
            }
        }

        // Point the screensaver module at the aerials extension so the lock screen
        // screensaver phase plays our video instead of a standalone module (e.g.
        // Ventura) that fades to black.
        configureScreensaverForAerials()

        return true
    }

    /// Set macOS screensaver to use the wallpaper aerials extension so the
    /// lock-screen screensaver phase plays our injected video continuously.
    private func configureScreensaverForAerials() {
        let aerialsPath = "/System/Library/ExtensionKit/Extensions/WallpaperAerialsExtension.appex"
        let current = UserDefaults(suiteName: "com.apple.screensaver")
        let currentModule = (current?.dictionary(forKey: "moduleDict") as? [String: Any])?["path"] as? String ?? ""
        if currentModule == aerialsPath { return }

        // defaults -currentHost write com.apple.screensaver moduleDict ...
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = [
            "-currentHost", "write", "com.apple.screensaver",
            "moduleDict",
            "-dict",
            "moduleName", "WallpaperAerialsExtension",
            "path", aerialsPath,
            "type", "0"
        ]
        try? task.run()
        task.waitUntilExit()
        NSLog("LivePaper: Screensaver module set to aerials extension (exit %d)", task.terminationStatus)
    }

    func remove() {
        guard let uuid = LivePaperConfig.shared.aerialsAssetID else { return }
        let fm = FileManager.default
        try? fm.removeItem(atPath: (videosDir as NSString).appendingPathComponent("\(uuid).mov"))
        try? fm.removeItem(atPath: (thumbsDir as NSString).appendingPathComponent("\(uuid).png"))
        removeFromEntriesJSON()
        LivePaperConfig.shared.aerialsAssetID = nil
        restartWallpaperAgent()
    }

    // MARK: - entries.json

    private func updateEntriesJSON(assetID: String, videoName: String) -> Bool {
        let fm = FileManager.default
        let manifestDir = (entriesPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: manifestDir, withIntermediateDirectories: true)

        var entries: [String: Any]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: entriesPath)),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            entries = parsed
        } else {
            // Create a minimal entries.json if it doesn't exist (clean install / Sequoia)
            entries = ["version": 1, "categories": [] as [Any], "assets": [] as [Any]]
            NSLog("LivePaper: entries.json not found, creating minimal structure")
        }

        var categories = entries["categories"] as? [[String: Any]] ?? []
        var assets = entries["assets"] as? [[String: Any]] ?? []

        let thumbFileURL = URL(fileURLWithPath: (thumbsDir as NSString).appendingPathComponent("\(assetID).png")).absoluteString
        let videoFileURL = URL(fileURLWithPath: (videosDir as NSString).appendingPathComponent("\(assetID).mov")).absoluteString

        // All subcategory fields are required by WallpaperAerialsCore's Swift Codable model
        let categoryEntry: [String: Any] = [
            "id": categoryID,
            "localizedNameKey": "LivePaper",
            "localizedDescriptionKey": "LivePaper custom wallpaper",
            "preferredOrder": 999,
            "representativeAssetID": assetID,
            "previewImage": thumbFileURL,
            "subcategories": [
                [
                    "id": subcategoryID,
                    "localizedNameKey": "LivePaper",
                    "localizedDescriptionKey": "LivePaper custom wallpaper",
                    "preferredOrder": 0,
                    "previewImage": thumbFileURL,
                    "representativeAssetID": assetID
                ]
            ]
        ]

        if let idx = categories.firstIndex(where: { ($0["id"] as? String) == categoryID }) {
            categories[idx] = categoryEntry
        } else {
            categories.append(categoryEntry)
        }

        let assetEntry: [String: Any] = [
            "id": assetID,
            "localizedNameKey": videoName,
            "accessibilityLabel": videoName,
            "shotID": "LIVEPAPER_CUSTOM",
            "showInTopLevel": true,
            "includeInShuffle": true,
            "preferredOrder": 0,
            "categories": [categoryID],
            "subcategories": [subcategoryID],
            "url-4K-SDR-240FPS": videoFileURL,
            "previewImage": thumbFileURL,
            "pointsOfInterest": ["0": "LIVEPAPER_0"]
        ]

        assets.removeAll { asset in
            guard let cats = asset["categories"] as? [String] else { return false }
            return cats.contains(categoryID)
        }
        assets.append(assetEntry)

        entries["categories"] = categories
        entries["assets"] = assets

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
            let tmpPath = entriesPath + ".tmp"
            let tmpURL = URL(fileURLWithPath: tmpPath)
            let destURL = URL(fileURLWithPath: entriesPath)
            try jsonData.write(to: tmpURL)
            _ = try FileManager.default.replaceItemAt(destURL, withItemAt: tmpURL)
            return true
        } catch {
            NSLog("LivePaper: Failed to write entries.json: \(error)")
            return false
        }
    }

    private func removeFromEntriesJSON() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: entriesPath)),
              var entries = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if var categories = entries["categories"] as? [[String: Any]] {
            categories.removeAll { ($0["id"] as? String) == categoryID }
            entries["categories"] = categories
        }
        if var assets = entries["assets"] as? [[String: Any]] {
            assets.removeAll { asset in
                guard let cats = asset["categories"] as? [String] else { return false }
                return cats.contains(categoryID)
            }
            entries["assets"] = assets
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: URL(fileURLWithPath: entriesPath))
        }
    }

    // MARK: - Thumbnail

    private func generateThumbnail(from videoURL: URL, to outputPath: String) {
        let asset = AVURLAsset(url: videoURL)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 480, height: 480)
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        gen.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
            guard let cgImage = cgImage else { return }
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: outputPath))
            }
        }
    }

    // MARK: - Store/Index.plist

    private func updateWallpaperStore(assetID: String) -> Bool {
        let configDict: [String: String] = ["assetID": assetID]
        guard let configData = try? PropertyListSerialization.data(
            fromPropertyList: configDict, format: .binary, options: 0
        ) else { return false }

        let storeURL = URL(fileURLWithPath: storePath)
        let storeDir = (storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: storeDir, withIntermediateDirectories: true)

        var store: [String: Any]
        if let data = try? Data(contentsOf: storeURL),
           let parsed = try? PropertyListSerialization.propertyList(
               from: data, options: .mutableContainersAndLeaves, format: nil
           ) as? [String: Any] {
            store = parsed
        } else {
            NSLog("LivePaper: Wallpaper store not found or unreadable — creating minimal store")
            store = [:]
        }

        let choice: [String: Any] = [
            "Provider": "com.apple.wallpaper.choice.aerials",
            "Files": [] as [Any],
            "Configuration": configData
        ]
        let content: [String: Any] = ["Choices": [choice]]
        let linked: [String: Any] = [
            "Content": content,
            "LastSet": Date(),
            "LastUse": Date()
        ]
        let entry: [String: Any] = [
            "Type": "linked",
            "Linked": linked
        ]

        store["SystemDefault"] = entry

        // Backdrop sets AllSpacesAndDisplays as a global override for all
        // displays and spaces — this is what makes the aerial show on the
        // lock screen for every display.
        store["AllSpacesAndDisplays"] = entry

        if var displays = store["Displays"] as? [String: Any] {
            for key in displays.keys { displays[key] = entry }
            store["Displays"] = displays
        }

        if var spaces = store["Spaces"] as? [String: Any] {
            for spaceKey in spaces.keys {
                if var space = spaces[spaceKey] as? [String: Any] {
                    if space["Default"] != nil { space["Default"] = entry }
                    if var spaceDisplays = space["Displays"] as? [String: Any] {
                        for dKey in spaceDisplays.keys { spaceDisplays[dKey] = entry }
                        space["Displays"] = spaceDisplays
                    }
                    spaces[spaceKey] = space
                }
            }
            store["Spaces"] = spaces
        }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
            let tmpURL = URL(fileURLWithPath: storePath + ".tmp")
            try data.write(to: tmpURL)
            _ = try FileManager.default.replaceItemAt(storeURL, withItemAt: tmpURL)
            return true
        } catch {
            NSLog("LivePaper: Failed to write wallpaper store: \(error)")
            return false
        }
    }

    func restartWallpaperAgent() {
        let cacheDir = NSString(string: "~/Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches/com.apple.wallpaper.caches/extension-com.apple.wallpaper.extension.aerials").expandingTildeInPath
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(atPath: cacheDir) {
            for item in items where item.hasSuffix(".bmp") {
                try? fm.removeItem(atPath: (cacheDir as NSString).appendingPathComponent(item))
            }
            let cvPath = (cacheDir as NSString).appendingPathComponent("cacheVersion.db")
            try? "{\"version\":0}".data(using: .utf8)?.write(to: URL(fileURLWithPath: cvPath))
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["WallpaperAgent"]
        try? task.run()
        task.waitUntilExit()
        NSLog("LivePaper: WallpaperAgent killed (exit code %d)", task.terminationStatus)
    }

    /// Check if WallpaperAgent is running
    func isWallpaperAgentRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "WallpaperAgent"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    /// Verify the agent restarts within a few seconds
    private func verifyAgentRestart() {
        // WallpaperAgent auto-restarts via launchd; wait up to 5 seconds
        for i in 1...10 {
            Thread.sleep(forTimeInterval: 0.5)
            if isWallpaperAgentRunning() {
                NSLog("LivePaper: WallpaperAgent restarted after %.1f seconds", Double(i) * 0.5)
                return
            }
        }
        NSLog("LivePaper: WARNING — WallpaperAgent did not restart within 5 seconds")
    }

    /// Check if injection is complete and agent is healthy
    func isInjectionHealthy() -> Bool {
        guard let uuid = LivePaperConfig.shared.aerialsAssetID else { return false }
        let fm = FileManager.default
        let videoPath = (videosDir as NSString).appendingPathComponent("\(uuid).mov")
        guard fm.fileExists(atPath: videoPath) else {
            NSLog("LivePaper: Injection unhealthy — video file missing")
            return false
        }
        guard fm.fileExists(atPath: entriesPath) else {
            NSLog("LivePaper: Injection unhealthy — entries.json missing")
            return false
        }
        guard isWallpaperAgentRunning() else {
            NSLog("LivePaper: Injection unhealthy — WallpaperAgent not running")
            return false
        }
        return true
    }
}
