// LivePaper – Screensaver Controller

import AppKit
import IOKit.pwr_mgt

class ScreensaverController {
    private var active = false
    private var clockWindows: [NSWindow] = []
    private weak var app: LivePaperApp?
    private var monitor: Any?
    private var sleepAssertionID: IOPMAssertionID = 0
    private var lockedBySystem = false
    private var pendingLockActivation = false
    private var enabled = false
    private var wasPausedBefore = false
    private var maintenanceTimer: Timer?

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
    }

    func start() { enabled = true }
    func stop() { enabled = false; dismiss() }

    @objc private func systemScreensaverDidStart() {
        guard enabled, !active else { return }
        activate()
    }

    @objc private func systemScreensaverDidStop() {
        if !lockedBySystem { dismiss() }
    }

    @objc private func screenLocked() {
        lockedBySystem = true
        if active {
            // Screensaver already active — raise above the lock screen shield immediately
            raiseWindowsAboveLock()
            // Burst of re-raises to beat the shield's timing
            for delay in [0.3, 0.8, 1.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self, self.lockedBySystem, self.active else { return }
                    self.raiseWindowsAboveLock()
                }
            }
        } else {
            pendingLockActivation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.tryPendingActivation()
            }
        }
    }

    @objc private func screenUnlocked() {
        lockedBySystem = false
        pendingLockActivation = false
        dismiss()
    }

    // MARK: - Window level management

    private func raiseWindowsAboveLock() {
        let shieldLevel = Int(CGShieldingWindowLevel())
        if let app = app {
            for v in app.videoViews { v.forceResume() }
            for w in app.wallpaperWindows {
                w.level = NSWindow.Level(rawValue: shieldLevel + 1)
                w.orderFrontRegardless()
            }
        }
        for w in clockWindows {
            w.level = NSWindow.Level(rawValue: shieldLevel + 2)
            w.orderFrontRegardless()
        }
    }

    private func raiseWindowsAboveScreensaver() {
        let videoLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        let clockLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        if let app = app {
            for v in app.videoViews { v.forceResume() }
            for w in app.wallpaperWindows {
                w.level = videoLevel
                w.orderFrontRegardless()
            }
        }
        for w in clockWindows {
            w.level = clockLevel
            w.orderFrontRegardless()
        }
    }

    private func maintenanceTick() {
        guard active else { return }
        if lockedBySystem {
            raiseWindowsAboveLock()
        } else {
            raiseWindowsAboveScreensaver()
        }
    }

    // MARK: - Screen configuration change while active

    func handleScreenChange() {
        guard active else { return }
        // Rebuild clock overlay windows for the new screen set
        for w in clockWindows { w.close() }
        clockWindows.removeAll()
        let clockLevel: NSWindow.Level
        if lockedBySystem {
            clockLevel = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 2)
        } else {
            clockLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        }
        for screen in NSScreen.screens {
            let cW: CGFloat = 1000, cH: CGFloat = 280
            let cWin = NSWindow(
                contentRect: NSRect(x: screen.frame.midX - cW/2, y: screen.frame.midY - cH/2 + 30, width: cW, height: cH),
                styleMask: .borderless, backing: .buffered, defer: false
            )
            cWin.level = clockLevel
            cWin.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cWin.isOpaque = false; cWin.backgroundColor = .clear
            cWin.ignoresMouseEvents = true; cWin.hasShadow = false
            cWin.isReleasedWhenClosed = false
            cWin.contentView = MondClockView(frame: NSRect(x: 0, y: 0, width: cW, height: cH), style: 0)
            cWin.orderFrontRegardless()
            clockWindows.append(cWin)
        }
        // Re-raise the newly created wallpaper windows
        if lockedBySystem {
            raiseWindowsAboveLock()
        } else {
            raiseWindowsAboveScreensaver()
        }
    }

    // MARK: - Activate / Dismiss

    private func activate() {
        guard !active, let app = app else { return }
        if app.displaySleeping {
            pendingLockActivation = true
            return
        }
        active = true

        wasPausedBefore = app.isPaused

        // Force-resume with pipeline restart — video may have been paused by
        // the occlusion handler or stalled after display sleep
        for v in app.videoViews { v.forceResume() }

        // Raise wallpaper ABOVE the system screensaver (+1 above .screenSaver)
        let videoLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        for w in app.wallpaperWindows {
            w.level = videoLevel
            w.orderFrontRegardless()
        }

        // Create clock overlay windows above the video (+2)
        let clockLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        for screen in NSScreen.screens {
            let cW: CGFloat = 1000, cH: CGFloat = 280
            let cWin = NSWindow(
                contentRect: NSRect(x: screen.frame.midX - cW/2, y: screen.frame.midY - cH/2 + 30, width: cW, height: cH),
                styleMask: .borderless, backing: .buffered, defer: false
            )
            cWin.level = clockLevel
            cWin.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cWin.isOpaque = false; cWin.backgroundColor = .clear
            cWin.ignoresMouseEvents = true; cWin.hasShadow = false
            cWin.isReleasedWhenClosed = false
            cWin.contentView = MondClockView(frame: NSRect(x: 0, y: 0, width: cW, height: cH), style: 0)
            cWin.orderFrontRegardless()
            clockWindows.append(cWin)
        }

        // Continuous maintenance: re-raise windows and force-resume video every second.
        // This beats the system screensaver reasserting its window level and
        // handles transitions between screensaver ↔ lock screen.
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.maintenanceTick()
        }
        maintenanceTimer?.tolerance = 0.3

        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            guard let s = self, !s.lockedBySystem else { return }
            s.dismiss()
        }

        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "LivePaper screensaver active" as CFString,
            &sleepAssertionID
        )
    }

    func completePendingLockActivation() {
        tryPendingActivation()
    }

    private func tryPendingActivation() {
        guard pendingLockActivation, lockedBySystem, !active else { return }
        if app?.displaySleeping == true { return }
        pendingLockActivation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.lockedBySystem, !self.active else { return }
            self.activate()
        }
    }

    func dismiss() {
        guard active else { return }
        active = false

        maintenanceTimer?.invalidate()
        maintenanceTimer = nil

        // Close clock overlay windows
        for w in clockWindows { w.close() }
        clockWindows.removeAll()

        // Lower wallpaper windows back to desktop level
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
            // Clear stale occlusion flag — it was set before we took over
            app.clearOcclusionPause()
            // Restore video playback state
            if wasPausedBefore {
                app.pause()
            } else {
                app.resume()
            }
        }

        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }
    var isActive: Bool { active }
}
