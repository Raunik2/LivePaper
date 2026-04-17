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
    private var looperObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

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

        // Use a single asset for both the player and the looper template.
        // This avoids duplicate file handles and ensures looper has correct duration.
        let asset = AVURLAsset(url: videoURL)
        let templateItem = AVPlayerItem(asset: asset)
        templateItem.preferredMaximumResolution = .zero

        player = AVQueuePlayer()
        player.volume = volume
        player.isMuted = (volume == 0)
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false

        // Create looper BEFORE play — looper inserts items into the queue
        playerLooper = AVPlayerLooper(player: player, templateItem: templateItem)
        observeLooper()
        observeItemStatus()
        observeEndTime()

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.drawsAsynchronously = true

        wantsLayer = true
        layer = playerLayer
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        playerLayer.contentsScale = scale
        player.play()
    }

    /// Observe the looper for failures — if it dies, rebuild automatically.
    private func observeLooper() {
        looperObservation?.invalidate()
        looperObservation = playerLooper.observe(\.status, options: [.new]) { [weak self] looper, _ in
            if looper.status == .failed {
                NSLog("LivePaper: AVPlayerLooper failed — %@",
                      looper.error?.localizedDescription ?? "unknown error")
                DispatchQueue.main.async {
                    guard let self = self, let url = self.currentURL else { return }
                    self.fullRebuild(url: url)
                }
            }
        }
    }

    func changeVideo(url: URL) {
        currentURL = url

        // Properly tear down old looper before creating new one
        looperObservation?.invalidate()
        itemObservation?.invalidate()
        removeEndObserver()
        playerLooper?.disableLooping()

        player.pause()
        player.removeAllItems()

        let asset = AVURLAsset(url: url)
        let templateItem = AVPlayerItem(asset: asset)
        templateItem.preferredMaximumResolution = .zero

        playerLooper = AVPlayerLooper(player: player, templateItem: templateItem)
        observeLooper()
        observeItemStatus()
        observeEndTime()
        player.play()
    }

    // MARK: - Item Status Observation (fixes black screen)

    private func observeItemStatus() {
        itemObservation?.invalidate()
        // Observe the *queue player's* currentItem — looper rotates items
        itemObservation = player.observe(\.currentItem?.status, options: [.new]) { [weak self] p, _ in
            guard let self = self else { return }
            if p.currentItem?.status == .failed {
                NSLog("LivePaper: PlayerItem failed — %@",
                      p.currentItem?.error?.localizedDescription ?? "unknown")
                DispatchQueue.main.async {
                    guard let url = self.currentURL else { return }
                    self.fullRebuild(url: url)
                }
            }
        }
    }

    // MARK: - End-of-Video Fallback (fixes looper not restarting)

    private func observeEndTime() {
        removeEndObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let endedItem = note.object as? AVPlayerItem else { return }
            // Only handle if it belongs to our player
            guard self.player.items().contains(where: { $0 === endedItem })
                  || self.player.currentItem === endedItem else { return }
            // If looper is healthy it will handle this; check after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if self.player.timeControlStatus != .playing {
                    NSLog("LivePaper: Looper didn't restart — seeking to start")
                    self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        self.player.play()
                    }
                }
            }
        }
    }

    private func removeEndObserver() {
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs); endObserver = nil }
    }

    func setVolume(_ vol: Float) {
        let v = max(0, min(1, vol))
        player.volume = v; player.isMuted = (v == 0)
    }
    func pause() { player.pause() }
    func resume() { player.play() }
    func setBatteryMode(_ on: Bool) {
        if on {
            player.currentItem?.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
            player.currentItem?.preferredPeakBitRate = 5_000_000
        } else {
            player.currentItem?.preferredMaximumResolution = .zero
            player.currentItem?.preferredPeakBitRate = 0
        }
    }

    func forceResume() {
        // Check looper health first
        if playerLooper.status == .failed {
            guard let url = currentURL else { return }
            NSLog("LivePaper: Looper failed during forceResume — rebuilding")
            fullRebuild(url: url)
            return
        }

        let item = player.currentItem
        if item == nil || item?.status == .failed || item?.error != nil {
            guard let url = currentURL else { return }
            NSLog("LivePaper: Player item in terminal state — rebuilding from %@", url.lastPathComponent)
            fullRebuild(url: url)
            return
        }
        player.play()
        if item?.status == .readyToPlay {
            player.seek(to: player.currentTime(), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        // Reconnect layer if GPU rendering pipeline broke
        if player.timeControlStatus == .playing && !playerLayer.isReadyForDisplay
            && player.currentTime().seconds > 0.5 {
            playerLayer.player = nil
            playerLayer.player = player
        }
    }

    /// Full teardown and rebuild of the entire player pipeline.
    func fullRebuild(url: URL) {
        NSLog("LivePaper: Full player rebuild for %@", url.lastPathComponent)
        currentURL = url

        // Tear down old looper and observations
        looperObservation?.invalidate()
        playerLooper?.disableLooping()
        player?.pause()
        playerLayer?.player = nil
        player?.removeAllItems()

        let asset = AVURLAsset(url: url)
        let templateItem = AVPlayerItem(asset: asset)
        templateItem.preferredMaximumResolution = .zero

        player = AVQueuePlayer()
        player.volume = volume
        player.isMuted = (volume == 0)
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false

        playerLooper = AVPlayerLooper(player: player, templateItem: templateItem)
        observeLooper()
        observeItemStatus()
        observeEndTime()

        playerLayer.player = player
        let scale = window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        playerLayer.contentsScale = scale
        player.play()
    }

    /// Capture a snapshot of the current video frame as NSImage
    func captureSnapshot() -> NSImage? {
        guard let url = currentURL else { return nil }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let time = player.currentTime()
        guard let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Check if the player is actually producing visible frames
    var isRenderingFrames: Bool {
        guard player.timeControlStatus == .playing else { return false }
        return playerLayer.isReadyForDisplay
    }

    func muteAudio() { player.isMuted = true }

    func unmuteAudio() {
        player.isMuted = (volume == 0)
        player.volume = volume
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let screen = window?.screen ?? NSScreen.main else { return }
        playerLayer?.contentsScale = screen.backingScaleFactor
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        playerLayer?.frame = bounds
        if let scale = window?.screen?.backingScaleFactor {
            playerLayer?.contentsScale = scale
        }
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

        // Backdrop's secret: keeps the window visible on the login/lock screen.
        let sel = NSSelectorFromString("setCanBecomeVisibleWithoutLogin:")
        if responds(to: sel) {
            perform(sel, with: true as NSNumber)
        }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
