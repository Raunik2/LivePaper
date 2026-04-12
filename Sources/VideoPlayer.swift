// LivePaper – Video Player View & Wallpaper Window

import AppKit
import AVFoundation

// MARK: - Video Player View (Max Quality, Optimized)

class VideoWallpaperView: NSView {
    private var player: AVQueuePlayer!
    private var playerLayer: AVPlayerLayer!
    private var playerLooper: AVPlayerLooper!
    private(set) var currentURL: URL?
    private var volume: Float = 0.0

    init(frame: NSRect, videoURL: URL, volume: Float = 0.0) {
        self.volume = volume
        super.init(frame: frame)
        setupPlayer(videoURL: videoURL)
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func makeBackingLayer() -> CALayer { return playerLayer ?? CALayer() }
    override var wantsUpdateLayer: Bool { true }

    private func setupPlayer(videoURL: URL) {
        currentURL = videoURL
        let asset = AVURLAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        item.preferredMaximumResolution = .zero

        player = AVQueuePlayer(playerItem: item)
        player.volume = volume
        player.isMuted = (volume == 0)
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false

        let looperItem = AVPlayerItem(asset: AVURLAsset(url: videoURL))
        looperItem.preferredMaximumResolution = .zero
        playerLooper = AVPlayerLooper(player: player, templateItem: looperItem)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.drawsAsynchronously = true

        wantsLayer = true
        layer = playerLayer
        player.play()
    }

    func changeVideo(url: URL) {
        currentURL = url
        player.pause()
        player.removeAllItems()
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredMaximumResolution = .zero
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    func setVolume(_ vol: Float) {
        let v = max(0, min(1, vol))
        player.volume = v; player.isMuted = (v == 0)
    }
    func pause() { player.pause() }
    func resume() { player.play() }
    func setBatteryMode(_ on: Bool) {
        if on {
            // Cap decode at 1080p and limit bitrate to reduce GPU/CPU power draw
            player.currentItem?.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
            player.currentItem?.preferredPeakBitRate = 5_000_000
        } else {
            // Full quality — no limits
            player.currentItem?.preferredMaximumResolution = .zero
            player.currentItem?.preferredPeakBitRate = 0
        }
    }
    func forceResume() {
        // Detect terminal states that require full player rebuild
        let item = player.currentItem
        if item == nil || item?.status == .failed || item?.error != nil {
            guard let url = currentURL else { return }
            NSLog("LivePaper: Player in terminal state — rebuilding from %@", url.lastPathComponent)
            changeVideo(url: url)
            return
        }
        player.play()
        // Seek to force the decoding pipeline to restart after display sleep
        if item?.status == .readyToPlay {
            player.seek(to: player.currentTime(), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        // Reconnect layer if GPU rendering pipeline broke (display sleep resets GPU)
        if player.timeControlStatus == .playing && !playerLayer.isReadyForDisplay
            && player.currentTime().seconds > 0.5 {
            playerLayer.player = nil
            playerLayer.player = player
        }
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        playerLayer?.frame = bounds
    }
}

// MARK: - Wallpaper Window

class WallpaperWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = true; hasShadow = false; backgroundColor = .black
        ignoresMouseEvents = true; isReleasedWhenClosed = false
        canHide = false; hidesOnDeactivate = false; isMovable = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
