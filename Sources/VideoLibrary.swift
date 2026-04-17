// LivePaper – Video Library

import AppKit
import AVFoundation

class VideoLibrary {
    static let shared = VideoLibrary()
    let libraryPath: String
    private let thumbsPath: String

    private var initialized = false

    private init() {
        libraryPath = NSString(string: "~/Movies/LivePaper").expandingTildeInPath
        thumbsPath = (libraryPath as NSString).appendingPathComponent(".thumbnails")
    }

    /// Ensures the library directory exists and bundled videos are copied.
    /// Called lazily on first access to avoid TCC prompt at app launch.
    func ensureReady() {
        guard !initialized else { return }
        initialized = true
        let fm = FileManager.default
        try? fm.createDirectory(atPath: libraryPath, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: thumbsPath, withIntermediateDirectories: true)
        copyBundledVideos()
    }

    private func copyBundledVideos() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let fm = FileManager.default
        let exts = ["mp4", "mov", "m4v"]
        guard let items = try? fm.contentsOfDirectory(atPath: resourceURL.path) else { return }
        for item in items {
            let ext = (item as NSString).pathExtension.lowercased()
            guard exts.contains(ext) else { continue }
            let dest = (libraryPath as NSString).appendingPathComponent(item)
            if !fm.fileExists(atPath: dest) {
                let src = resourceURL.appendingPathComponent(item)
                try? fm.copyItem(at: src, to: URL(fileURLWithPath: dest))
            }
        }
    }

    func videoFiles() -> [URL] {
        ensureReady()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: libraryPath) else { return [] }
        let exts = ["mp4", "mov", "m4v", "avi"]
        return items
            .filter { !$0.hasPrefix(".") && exts.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
            .map { URL(fileURLWithPath: (libraryPath as NSString).appendingPathComponent($0)) }
    }

    func thumbnail(for url: URL, size: CGSize = CGSize(width: 240, height: 135)) -> NSImage? {
        ensureReady()
        let name = url.deletingPathExtension().lastPathComponent
        let thumbPath = (thumbsPath as NSString).appendingPathComponent("\(name).png")
        if FileManager.default.fileExists(atPath: thumbPath),
           let img = NSImage(contentsOfFile: thumbPath) { return img }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = size
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: thumbPath))
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    func removeVideo(at url: URL) -> Bool {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let thumbPath = (thumbsPath as NSString).appendingPathComponent("\(name).png")
        do {
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
            if fm.fileExists(atPath: thumbPath) {
                try fm.removeItem(atPath: thumbPath)
            }
            return true
        } catch {
            NSLog("LivePaper: Failed to remove video: \(error)")
            return false
        }
    }
}
