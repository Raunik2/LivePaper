// LivePaper – Mond Clock View & Clock Window

import AppKit

// MARK: - Mond Font Helper

func mondFont(size: CGFloat) -> NSFont {
    if let f = NSFont(name: "Anurati-Regular", size: size) { return f }
    if let f = NSFont(name: "Anurati", size: size) { return f }
    return NSFont.systemFont(ofSize: size, weight: .ultraLight)
}

// MARK: - Mond Clock View

class MondClockView: NSView {
    private var timer: Timer?
    private var clockStyle: Int = 0

    private let mondWhite = NSColor(white: 1.0, alpha: 0.95)
    private let mondLight = NSColor(white: 0.85, alpha: 0.85)

    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE"; return f }()
    private static let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d MMMM, yyyy"; return f }()
    private static let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f }()
    private static let timeSecFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm:ss a"; return f }()

    init(frame: NSRect, style: Int = 0) {
        self.clockStyle = style
        super.init(frame: frame)
        wantsLayer = true; layer?.backgroundColor = .clear
        let interval: TimeInterval = (style == 1) ? 1.0 : 30.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        timer?.tolerance = interval * 0.2
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    func setStyle(_ s: Int) {
        clockStyle = s
        timer?.invalidate()
        let interval: TimeInterval = (s == 1) ? 1.0 : 30.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        timer?.tolerance = interval * 0.2
        needsDisplay = true
    }

    private func shadow() -> NSShadow {
        let s = NSShadow()
        s.shadowColor = NSColor(white: 0, alpha: 0.5)
        s.shadowOffset = NSSize(width: 0, height: -1)
        s.shadowBlurRadius = 6
        return s
    }

    override func draw(_ dirtyRect: NSRect) {
        guard NSGraphicsContext.current != nil else { return }
        let large = clockStyle != 2
        let showSec = clockStyle == 1
        drawMond(large: large, showSeconds: showSec)
    }

    private func drawMond(large: Bool, showSeconds: Bool) {
        let now = Date()
        let shd = shadow()
        let cx = bounds.midX
        let ds: CGFloat = large ? 80 : 44
        let is_: CGFloat = large ? 18 : 13
        let dk: CGFloat = large ? 18 : 12
        let ik: CGFloat = large ? 3.5 : 2.5

        let dayStr = MondClockView.dayFmt.string(from: now).uppercased()
        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: mondFont(size: ds), .foregroundColor: mondWhite,
            .kern: dk as NSNumber, .shadow: shd
        ]
        let dayAS = NSAttributedString(string: dayStr, attributes: dayAttrs)
        let daySz = dayAS.size()

        let g1: CGFloat = large ? 18 : 12
        let g2: CGFloat = large ? 16 : 10
        let totalH = daySz.height + g1 + is_ * 1.4 + g2 + is_ * 1.4
        var y = bounds.midY + totalH / 2 - daySz.height
        dayAS.draw(at: NSPoint(x: cx - daySz.width / 2, y: y))

        y -= g1
        let dateStr = MondClockView.dateFmt.string(from: now).uppercased() + "."
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: is_, weight: .light), .foregroundColor: mondLight,
            .kern: ik as NSNumber, .shadow: shd
        ]
        let dateAS = NSAttributedString(string: dateStr, attributes: dateAttrs)
        let dateSz = dateAS.size()
        y -= dateSz.height
        dateAS.draw(at: NSPoint(x: cx - dateSz.width / 2, y: y))

        y -= g2
        let timeFmt = showSeconds ? MondClockView.timeSecFmt : MondClockView.timeFmt
        let timeStr = "- " + timeFmt.string(from: now).uppercased() + " -"
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: is_, weight: .light), .foregroundColor: mondLight,
            .kern: (large ? 2.5 : 2.0) as NSNumber, .shadow: shd
        ]
        let timeAS = NSAttributedString(string: timeStr, attributes: timeAttrs)
        let timeSz = timeAS.size()
        y -= timeSz.height
        timeAS.draw(at: NSPoint(x: cx - timeSz.width / 2, y: y))
    }

    deinit { timer?.invalidate() }
}

// MARK: - Clock Overlay Window

class ClockWindow: NSWindow {
    init(screen: NSScreen) {
        let w: CGFloat = 900, h: CGFloat = 250
        super.init(
            contentRect: NSRect(x: screen.frame.midX - w/2, y: screen.frame.midY - h/2 + 40, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = false; hasShadow = false; backgroundColor = .clear
        ignoresMouseEvents = true; isReleasedWhenClosed = false; hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
