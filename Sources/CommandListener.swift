// LivePaper – Pipe Command Listener

import AppKit

class CommandListener {
    private let path = "/tmp/livepaper.pipe"
    private let app: LivePaperApp

    init(app: LivePaperApp) {
        self.app = app
        unlink(path); mkfifo(path, 0o644)
        DispatchQueue.global(qos: .utility).async { [weak self] in self?.listen() }
    }

    private func listen() {
        while true {
            guard let d = try? String(contentsOfFile: path, encoding: .utf8) else {
                Thread.sleep(forTimeInterval: 0.5); continue
            }
            let cmd = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cmd.isEmpty { DispatchQueue.main.async { [weak self] in self?.handle(cmd) } }
            unlink(path); mkfifo(path, 0o644)
        }
    }

    private func handle(_ c: String) {
        let p = c.split(separator: " ", maxSplits: 1)
        switch p.first {
        case "pause": app.pause()
        case "resume", "play": app.resume()
        case "change": if p.count > 1 { app.changeVideo(url: URL(fileURLWithPath: String(p[1]))) }
        case "volume": if p.count > 1, let v = Float(p[1]) { app.setVolume(v / 100.0) }
        case "dashboard": app.dashboard?.show()
        case "clock":
            if p.count > 1 {
                switch p[1] {
                case "on": app.showClock()
                case "off": app.hideClock()
                case "0","1","2": if let s = Int(p[1]) { app.setClockStyle(s) }
                default: break
                }
            }
        case "quit": NSApplication.shared.terminate(nil)
        default: break
        }
    }

    func cleanup() { unlink(path) }
}
