// LivePaper – Screensaver & Lock-Screen Controller
//
// Architecture (based on Backdrop reverse-engineering):
//   • Lock Screen: On lock, we ORDER OUT our wallpaper windows so the system
//     aerials screensaver (playing our injected aerial video) is visible.
//     macOS's own screensaver continues playing on the lock screen — we just
//     need to get out of the way. On unlock, we bring our windows back.
//   • Screensaver (idle trigger): we raise our wallpaper window above the
//     system screensaver and show a clock overlay.
//   • Snapshot fallback: periodically capture video frames and set as macOS
//     desktop wallpaper so there's never a black screen.

import AppKit
import IOKit.pwr_mgt

class ScreensaverController {
    private var active = false
    private var clockWindows: [NSWindow] = []
    private weak var app: LivePaperApp?
    private var monitor: Any?
    private var sleepAssertionID: IOPMAssertionID = 0
    private var lockedBySystem = false
    private var enabled = false
    private var wasPausedBefore = false
    private var maintenanceTimer: Timer?
    private var rebuildCount = 0
    private var lastRecoveryTime: Date = .distantPast
    private var snapshotTimer: Timer?

    init(app: LivePaperApp) {
        self.app = app

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(systemScreensaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didStart"), object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(systemScreensaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didStop"), object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"), object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil
        )

        startSnapshotTimer()
    }

    func start() { enabled = true }
    func stop() { enabled = false; dismiss(); snapshotTimer?.invalidate(); snapshotTimer = nil }

    // MARK: - Snapshot Fallback
    // Captures frames from video views and sets as macOS desktop wallpaper
    // for each screen so there's always something visible behind the window.

    private func startSnapshotTimer() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.captureAndSetSnapshots()
        }
        snapshotTimer?.tolerance = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.captureAndSetSnapshots()
        }
    }

    private func captureAndSetSnapshots() {
        guard let app = app else { return }
        let snapshotDir = NSString(string: "~/Library/Application Support/LivePaper").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: snapshotDir, withIntermediateDirectories: true)

        let screens = NSScreen.screens
        for (idx, view) in app.videoViews.enumerated() {
            guard let snapshot = view.captureSnapshot() else { continue }
            guard let tiffData = snapshot.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData),
                  let pngData = rep.representation(using: .png, properties: [:]) else { continue }
            let path = (snapshotDir as NSString).appendingPathComponent("wallpaper_snapshot_\(idx).png")
            do {
                try pngData.write(to: URL(fileURLWithPath: path))
                let url = URL(fileURLWithPath: path)
                if idx < screens.count {
                    try NSWorkspace.shared.setDesktopImageURL(url, for: screens[idx], options: [:])
                } else {
                    for screen in screens {
                        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                    }
                }
            } catch {
                NSLog("LivePaper: Snapshot fallback failed for screen %d: %@", idx, error.localizedDescription)
            }
        }
    }

    // MARK: - Notifications

    @objc private func systemScreensaverDidStart() {
        guard enabled, !active else { return }
        activate()
    }

    @objc private func systemScreensaverDidStop() {
        if !lockedBySystem { dismiss() }
    }

    @objc private func screenLocked() {
        lockedBySystem = true
        let agentRunning = AerialsInjector().isWallpaperAgentRunning()
        NSLog("LivePaper: Screen locked — hiding windows (WallpaperAgent running: %d)", agentRunning ? 1 : 0)

        // Do NOT call injectToAerials() here — it kills WallpaperAgent,
        // which races with the lock screen transition and causes a black
        // screen.  Instead we verify after unlock (see screenUnlocked)
        // so the agent has time to restart before the next lock.

        if active {
            dismissForLock()
        }
        hideWallpaperWindows()
    }

    @objc private func screenUnlocked() {
        NSLog("LivePaper: Screen unlocked — restoring windows")
        lockedBySystem = false
        showWallpaperWindows()

        // Always re-inject after unlock so the agent is primed for the
        // next lock cycle.  The 2-second delay avoids interfering with
        // the unlock animation.  The inject call now verifies the agent
        // restarts successfully before returning.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            NSLog("LivePaper: Post-unlock aerials refresh")
            self.app?.injectToAerials(forceRestart: true)
        }
    }

    // MARK: - Hide/Show wallpaper windows for lock screen
    // On lock: orderOut our wallpaper windows so the system aerials
    // screensaver (playing our injected video) is visible.
    // On unlock: bring them back.

    private func hideWallpaperWindows() {
        guard let app = app else { return }
        for v in app.videoViews { v.pause() }
        for w in app.wallpaperWindows { w.orderOut(nil) }
        for w in app.clockWindows { w.orderOut(nil) }
    }

    private func showWallpaperWindows() {
        guard let app = app else { return }
        let wpLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        let ckLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
        for w in app.wallpaperWindows {
            w.level = wpLevel
            w.orderFront(nil)
        }
        for w in app.clockWindows {
            w.level = ckLevel
            w.orderFront(nil)
        }
        for v in app.videoViews { v.unmuteAudio() }
        if !app.isPaused {
            for v in app.videoViews { v.resume() }
        }
    }

    // MARK: - Screensaver (idle trigger overlay)

    private func activate() {
        guard !active, let app = app else { return }
        if app.displaySleeping { return }
        active = true
        rebuildCount = 0
        lastRecoveryTime = .distantPast
        wasPausedBefore = app.isPaused

        for v in app.videoViews { v.muteAudio() }
        captureAndSetSnapshots()

        // Ensure players are running
        for v in app.videoViews { v.forceResume() }

        // Raise above system screensaver
        let videoLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        for w in app.wallpaperWindows {
            w.level = videoLevel
            w.orderFrontRegardless()
        }

        createClockOverlays(level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2))

        // Recovery checks
        for delay in [0.8, 2.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.active else { return }
                self.checkAndRecoverPlayback()
                self.reraiseWindows()
            }
        }

        startMaintenanceTimer()

        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            guard let s = self, !s.lockedBySystem else { return }
            s.dismiss()
        }

        startSleepAssertion()
    }

    // MARK: - Clock overlays

    private func createClockOverlays(level: NSWindow.Level) {
        for w in clockWindows { w.close() }
        clockWindows.removeAll()
        for screen in NSScreen.screens {
            let cW: CGFloat = 1000, cH: CGFloat = 280
            let cWin = NSWindow(
                contentRect: NSRect(x: screen.frame.midX - cW/2, y: screen.frame.midY - cH/2 + 120, width: cW, height: cH),
                styleMask: .borderless, backing: .buffered, defer: false
            )
            cWin.level = level
            cWin.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cWin.isOpaque = false; cWin.backgroundColor = .clear
            cWin.ignoresMouseEvents = true; cWin.hasShadow = false
            cWin.isReleasedWhenClosed = false
            cWin.contentView = MondClockView(frame: NSRect(x: 0, y: 0, width: cW, height: cH), style: 0)
            cWin.orderFrontRegardless()
            clockWindows.append(cWin)
        }
    }

    private func reraiseWindows() {
        guard let app = app else { return }
        let videoLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        let clockLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        for v in app.videoViews { v.forceResume() }
        for w in app.wallpaperWindows {
            w.level = videoLevel
            w.orderFrontRegardless()
        }
        for w in clockWindows {
            w.level = clockLevel
            w.orderFrontRegardless()
        }
    }

    private func checkAndRecoverPlayback() {
        guard let app = app else { return }
        var anyBroken = false
        for v in app.videoViews where !v.isRenderingFrames {
            anyBroken = true; break
        }
        guard anyBroken else { return }

        rebuildCount += 1
        if rebuildCount <= 2 {
            NSLog("LivePaper: Recovery #%d — reloading video", rebuildCount)
            app.reloadAllPlayers()
        } else {
            NSLog("LivePaper: Recovery #%d — full rebuild", rebuildCount)
            app.rebuildAllPlayers()
        }
    }

    private func startMaintenanceTimer() {
        maintenanceTimer?.invalidate()
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.maintenanceTick()
        }
        maintenanceTimer?.tolerance = 0.5
    }

    private func maintenanceTick() {
        guard active, let app = app else { return }

        var anyNotRendering = false
        for v in app.videoViews where !v.isRenderingFrames {
            anyNotRendering = true; break
        }

        if anyNotRendering {
            let now = Date()
            if now.timeIntervalSince(lastRecoveryTime) > 4.0 {
                lastRecoveryTime = now
                checkAndRecoverPlayback()
            }
        }

        reraiseWindows()
    }

    private func startSleepAssertion() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LivePaper screensaver active" as CFString,
            &sleepAssertionID
        )
    }

    // MARK: - Screen config change while active

    func handleScreenChange() {
        guard active else { return }
        let level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        createClockOverlays(level: level)
        reraiseWindows()
    }

    func completePendingLockActivation() {
        // After display wake: if we were locked, show wallpaper windows
        // since displayDidWake fires before screenUnlocked
    }

    // MARK: - Dismiss (for screensaver → normal transition)

    func dismiss() {
        guard active else { return }
        active = false

        maintenanceTimer?.invalidate()
        maintenanceTimer = nil

        for w in clockWindows { w.close() }
        clockWindows.removeAll()

        if let app = app {
            let wpLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            for w in app.wallpaperWindows {
                w.level = wpLevel
                w.orderFront(nil)
            }
            let ckLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
            for w in app.clockWindows {
                w.level = ckLevel
                w.orderFront(nil)
            }
            for v in app.videoViews { v.unmuteAudio() }
            app.clearOcclusionPause()
            if wasPausedBefore { app.pause() } else { app.resume() }
        }

        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    // MARK: - Dismiss for lock (don't restore windows — lock handler does that)

    private func dismissForLock() {
        guard active else { return }
        active = false

        maintenanceTimer?.invalidate()
        maintenanceTimer = nil

        for w in clockWindows { w.close() }
        clockWindows.removeAll()

        // Don't restore wallpaper window levels here — hideWallpaperWindows
        // will orderOut them. showWallpaperWindows on unlock restores them.

        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    var isActive: Bool { active }
}
