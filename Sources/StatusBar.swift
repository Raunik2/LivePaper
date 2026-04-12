// LivePaper – Status Bar Controller

import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var app: LivePaperApp

    init(app: LivePaperApp) {
        self.app = app
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "LivePaper")
            btn.image?.size = NSSize(width: 18, height: 18)
            btn.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.autoenablesItems = false

        let np = NSMenuItem(title: "Now Playing:", action: nil, keyEquivalent: ""); np.isEnabled = false
        menu.addItem(np)
        let vn = NSMenuItem(title: "  \(app.currentVideoName)", action: nil, keyEquivalent: "")
        vn.isEnabled = false; vn.tag = 100
        menu.addItem(vn)
        menu.addItem(.separator())

        let dash = NSMenuItem(title: "Open Dashboard...", action: #selector(openDash), keyEquivalent: ",")
        dash.target = self; menu.addItem(dash)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause", action: #selector(togglePause(_:)), keyEquivalent: "p")
        pause.target = self; pause.tag = 200; menu.addItem(pause)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit LivePaper", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc func openDash() { app.dashboard?.show() }
    @objc func togglePause(_ s: NSMenuItem) {
        if app.isPaused { app.resume(); s.title = "Pause" } else { app.pause(); s.title = "Resume" }
    }
    @objc func quitApp() { NSApplication.shared.terminate(nil) }

    func updateNowPlaying() {
        if let m = statusItem.menu, let n = m.item(withTag: 100) { n.title = "  \(app.currentVideoName)" }
    }
}
