// LivePaper – Window Persistence Manager

import AppKit

class WindowPersistenceManager {
    private var timer: Timer?
    private weak var app: LivePaperApp?

    init(app: LivePaperApp) { self.app = app }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let app = self?.app else { return }
            // Don't reset levels while screensaver is active — it manages its own levels
            if app.screensaverController?.isActive == true { return }
            let wp = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            let ck = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
            for w in app.wallpaperWindows { if !w.isVisible { w.orderFront(nil) }; w.level = wp }
            for w in app.clockWindows { if !w.isVisible { w.orderFront(nil) }; w.level = ck }
        }
        timer?.tolerance = 2
    }
    func stop() { timer?.invalidate() }
}
