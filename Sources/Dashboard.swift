// LivePaper – Dashboard (SwiftUI)
// Uses SwiftUI for automatic layout — no manual frame math, no overlap bugs.
// Embedded in NSWindow via NSHostingView for compatibility with the AppKit app.

import SwiftUI
import AppKit
import AVFoundation

// MARK: - Accent Colors (SwiftUI)

private let accentPurple = Color(red: 0.56, green: 0.40, blue: 1.00)
private let accentCyan   = Color(red: 0.25, green: 0.88, blue: 0.82)
private let mutedGray    = Color(white: 0.50)
private let cardBg       = Color(white: 0.15)
private let dashBg       = Color(red: 0.11, green: 0.11, blue: 0.14)

// Keep DashAccent for backward compat (used in other files if needed)
struct DashAccent {
    static let purple   = NSColor(calibratedRed: 0.56, green: 0.40, blue: 1.00, alpha: 1)
    static let cyan     = NSColor(calibratedRed: 0.25, green: 0.88, blue: 0.82, alpha: 1)
}

// MARK: - Observable State

class DashboardState: ObservableObject {
    @Published var videoName: String = "No video selected"
    @Published var thumbImage: NSImage? = nil
    @Published var isPaused: Bool = false
    @Published var volume: Double = 0
    @Published var screensaverEnabled: Bool = true
    @Published var clockEnabled: Bool = true
    @Published var clockStyle: Int = 0
    @Published var lockScreenEnabled: Bool = true
    @Published var pauseOnBattery: Bool = false
    @Published var libraryVideos: [URL] = []
    @Published var currentVideoPath: String = ""

    weak var app: LivePaperApp?

    func refresh() {
        guard let app = app else { return }
        videoName = app.currentVideoName
        isPaused = app.isPaused
        volume = Double(LivePaperConfig.shared.volume) * 100
        screensaverEnabled = LivePaperConfig.shared.screensaverEnabled
        clockEnabled = app.clockEnabled
        clockStyle = LivePaperConfig.shared.clockStyle
        lockScreenEnabled = LivePaperConfig.shared.lockScreenEnabled
        pauseOnBattery = LivePaperConfig.shared.pauseOnBattery
        currentVideoPath = app.currentVideoURL.path
        libraryVideos = VideoLibrary.shared.videoFiles()
        if app.currentVideoURL.path != "/dev/null" {
            thumbImage = VideoLibrary.shared.thumbnail(for: app.currentVideoURL, size: CGSize(width: 320, height: 180))
        }
    }
}

// MARK: - Main Dashboard View

struct DashboardView: View {
    @ObservedObject var state: DashboardState
    var actions: DashboardActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.top, 12)

                LinearGradient(colors: [accentPurple, accentCyan], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
                    .cornerRadius(1)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                sectionLabel("NOW PLAYING")
                nowPlayingCard
                    .padding(.bottom, 20)

                sectionLabel("VIDEO LIBRARY")
                libraryGrid
                    .padding(.bottom, 16)

                actionButtons
                    .padding(.bottom, 24)

                sectionLabel("SETTINGS")
                settingsCard
                    .padding(.bottom, 24)

                bottomBar
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dashBg)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIVEPAPER")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                Spacer()
                Text("v3.0")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mutedGray)
            }
            Text("Live Wallpaper Engine  ·  Mond Clock")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(mutedGray)
        }
    }

    // MARK: - Now Playing

    private var nowPlayingCard: some View {
        HStack(spacing: 18) {
            Group {
                if let img = state.thumbImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.12))
                        .frame(width: 160, height: 90)
                }
            }
            .shadow(color: accentPurple.opacity(0.5), radius: 12, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 12) {
                Text(state.videoName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 10) {
                    Button(action: actions.play) {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .disabled(!state.isPaused)
                    .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

                    Button(action: actions.pause) {
                        Label("Pause", systemImage: "pause.fill")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .disabled(state.isPaused)
                    .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                }

                HStack(spacing: 8) {
                    Text("Vol")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(mutedGray)
                    Slider(value: Binding(
                        get: { state.volume },
                        set: { actions.setVolume($0) }
                    ), in: 0...100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Library Grid

    private var libraryGrid: some View {
        Group {
            if state.libraryVideos.isEmpty {
                VStack(spacing: 6) {
                    Text("No videos yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(white: 0.50))
                    Text("Choose a file below or download from moewalls.com")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.40))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(cardBg)
                .cornerRadius(14)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(state.libraryVideos.enumerated()), id: \.offset) { index, url in
                        videoThumbnail(url: url, index: index)
                    }
                }
                .padding(12)
                .background(cardBg)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
            }
        }
    }

    private func videoThumbnail(url: URL, index: Int) -> some View {
        let isActive = url.path == state.currentVideoPath
        return Button(action: { actions.selectVideo(index) }) {
            VStack(spacing: 6) {
                Group {
                    if let thumb = VideoLibrary.shared.thumbnail(for: url) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 80)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(white: 0.12))
                            .frame(height: 80)
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? accentCyan : Color.clear, lineWidth: 2)
                )

                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? accentCyan : Color(white: 0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .buttonStyle(.plain)
        .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: actions.chooseFile) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                    Text("Choose Video File…")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(accentPurple.opacity(0.15))
                .foregroundColor(accentPurple)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentPurple.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

            Button(action: actions.browseMoewalls) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                    Text("Browse More Live Wallpapers")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundColor(Color(white: 0.65))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { state.lockScreenEnabled },
                set: { actions.toggleLockScreen($0) }
            )) {
                Text("Show on Lock Screen & Screensaver")
                    .font(.system(size: 14))
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: Binding(
                get: { state.pauseOnBattery },
                set: { actions.togglePauseOnBattery($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause video on battery")
                        .font(.system(size: 14))
                    Text("Off = lower quality on battery · On = pause completely")
                        .font(.system(size: 11))
                        .foregroundColor(mutedGray)
                }
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { state.clockEnabled },
                    set: { actions.toggleClock($0) }
                )) {
                    Text("Show Mond clock on desktop")
                        .font(.system(size: 14))
                }
                .toggleStyle(.checkbox)

                Spacer()

                Text("Clock Style:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(white: 0.70))
                    .padding(.trailing, 8)

                Picker("", selection: Binding(
                    get: { state.clockStyle },
                    set: { actions.setClockStyle($0) }
                )) {
                    Text("Classic").tag(0)
                    Text("Classic + Seconds").tag(1)
                    Text("Small").tag(2)
                }
                .labelsHidden()
                .frame(width: 180)
                .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
        }
        .padding(18)
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("Quit") {
                actions.quit()
            }
            .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            Spacer()
            Text("Created by Raunak Gupta")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.38))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(mutedGray)
            .padding(.bottom, 10)
    }
}

// MARK: - Actions Struct

struct DashboardActions {
    var play: () -> Void = {}
    var pause: () -> Void = {}
    var setVolume: (Double) -> Void = { _ in }
    var chooseFile: () -> Void = {}
    var browseMoewalls: () -> Void = {}
    var selectVideo: (Int) -> Void = { _ in }
    var toggleClock: (Bool) -> Void = { _ in }
    var setClockStyle: (Int) -> Void = { _ in }
    var toggleLockScreen: (Bool) -> Void = { _ in }
    var togglePauseOnBattery: (Bool) -> Void = { _ in }
    var quit: () -> Void = {}
}

// MARK: - Dashboard Controller (AppKit bridge)

class DashboardController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var app: LivePaperApp?
    private var state = DashboardState()

    init(app: LivePaperApp) {
        self.app = app
        super.init()
        state.app = app
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        state.refresh()
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindow()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func updateVideoLabel() {
        state.refresh()
    }

    // MARK: - Build Window

    private func buildWindow() {
        let W: CGFloat = 720, H: CGFloat = 860
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)

        window = NSWindow(
            contentRect: NSRect(x: sf.midX - W/2, y: sf.midY - H/2, width: W, height: H),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window!.title = "LivePaper"
        window!.isReleasedWhenClosed = false
        window!.level = .floating
        window!.appearance = NSAppearance(named: .darkAqua)
        window!.delegate = self
        window!.titlebarAppearsTransparent = true
        window!.titleVisibility = .hidden
        window!.isMovableByWindowBackground = true
        window!.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)

        let actions = DashboardActions(
            play:              { [weak self] in self?.app?.resume(); self?.state.isPaused = false },
            pause:             { [weak self] in self?.app?.pause(); self?.state.isPaused = true },
            setVolume:         { [weak self] v in
                let vol = Float(v) / 100.0
                LivePaperConfig.shared.volume = vol
                self?.app?.setVolume(vol)
                self?.state.volume = v
            },
            chooseFile:        { [weak self] in self?.chooseWallpaper() },
            browseMoewalls:    {
                if let url = URL(string: "https://moewalls.com/") {
                    NSWorkspace.shared.open(url)
                }
            },
            selectVideo:       { [weak self] idx in self?.selectLibraryVideo(idx) },
            toggleClock:       { [weak self] on in
                LivePaperConfig.shared.clockEnabled = on
                self?.state.clockEnabled = on
                if on { self?.app?.showClock() } else { self?.app?.hideClock() }
            },
            setClockStyle:     { [weak self] s in
                LivePaperConfig.shared.clockStyle = s
                self?.state.clockStyle = s
                self?.app?.setClockStyle(s)
            },
            toggleLockScreen:  { [weak self] on in
                LivePaperConfig.shared.lockScreenEnabled = on
                self?.state.lockScreenEnabled = on
                if on {
                    self?.app?.injectToAerials()
                } else {
                    self?.app?.removeFromAerials()
                }
            },
            togglePauseOnBattery: { [weak self] on in
                LivePaperConfig.shared.pauseOnBattery = on
                self?.state.pauseOnBattery = on
                // Re-apply battery mode with new setting
                if self?.app?.batteryMonitor?.isOnBattery == true {
                    if on { self?.app?.enterBatteryMode() }
                    else { self?.app?.exitBatteryMode(); self?.app?.enterBatteryMode() }
                }
            },
            quit:              { NSApplication.shared.terminate(nil) }
        )

        let dashView = DashboardView(state: state, actions: actions)
        let hostingView = NSHostingView(rootView: dashView)
        hostingView.frame = NSRect(x: 0, y: 0, width: W, height: H)
        hostingView.autoresizingMask = [.width, .height]

        window!.contentView = hostingView
    }

    // MARK: - Actions

    private func chooseWallpaper() {
        guard let url = pickVideo(title: "Choose Wallpaper Video") else { return }
        let destPath = (VideoLibrary.shared.libraryPath as NSString).appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destPath) {
            try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destPath))
        }
        app?.changeVideo(url: url)
        LivePaperConfig.shared.wallpaperVideoPath = url.path
        state.refresh()
    }

    private func selectLibraryVideo(_ index: Int) {
        let videos = state.libraryVideos
        guard index >= 0, index < videos.count else { return }
        let url = videos[index]
        app?.changeVideo(url: url)
        LivePaperConfig.shared.wallpaperVideoPath = url.path
        state.refresh()
    }

    private func pickVideo(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
