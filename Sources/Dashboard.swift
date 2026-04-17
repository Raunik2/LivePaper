// LivePaper – Dashboard (SwiftUI)
// Uses SwiftUI for automatic layout — no manual frame math, no overlap bugs.
// Embedded in NSWindow via NSHostingView for compatibility with the AppKit app.

import SwiftUI
import AppKit

// MARK: - Accent Colors (SwiftUI)

private let accentPurple = Color(red: 0.56, green: 0.40, blue: 1.00)
private let accentCyan   = Color(red: 0.25, green: 0.88, blue: 0.82)
private let mutedGray    = Color(white: 0.50)
private let cardBg       = Color(white: 0.15)
private let dashBg       = Color(red: 0.11, green: 0.11, blue: 0.14)

// MARK: - Observable State

class DashboardState: ObservableObject {
    @Published var videoName: String = "No video selected"
    @Published var thumbImage: NSImage? = nil
    @Published var isPaused: Bool = false
    @Published var volume: Double = 0
    @Published var clockEnabled: Bool = true
    @Published var clockStyle: Int = 0
    @Published var lockScreenEnabled: Bool = true
    @Published var pauseOnBattery: Bool = false
    @Published var libraryVideos: [URL] = []
    @Published var currentVideoPath: String = ""
    @Published var youtubeURL: String = ""
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0  // 0.0 to 1.0
    @Published var downloadStatus: String = ""
    @Published var isProcessing: Bool = false
    @Published var processStatus: String = ""

    weak var app: LivePaperApp?

    func refresh() {
        guard let app = app else { return }
        videoName = app.currentVideoName
        isPaused = app.isPaused
        volume = Double(LivePaperConfig.shared.volume) * 100
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
                Text("v3.0")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mutedGray)
                Spacer()
                Text("Created by Raunak Gupta")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.38))
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
        return ZStack(alignment: .topTrailing) {
            Button(action: { actions.selectVideo(index) }) {
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

            // Remove button (X)
            Button(action: { actions.removeVideo(index) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.7))
                    .background(Circle().fill(Color(white: 0.1)))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
            .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Progress Section — shown between library and buttons when active
            if state.isDownloading || state.isProcessing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: state.isDownloading ? "arrow.down.circle.fill" : "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(state.isDownloading ? accentCyan : accentPurple)
                        Text(state.isDownloading ? state.downloadStatus : state.processStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        if state.downloadProgress > 0 {
                            Text("\(Int(state.downloadProgress * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(state.isDownloading ? accentCyan : accentPurple)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.2))
                                .frame(height: 6)
                            if state.downloadProgress > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [accentPurple, accentCyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(state.downloadProgress), height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: state.downloadProgress)
                            } else {
                                // Indeterminate: pulsing bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [accentPurple, accentCyan], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * 0.3, height: 6)
                                    .opacity(0.7)
                            }
                        }
                    }
                    .frame(height: 6)
                }
                .padding(14)
                .background(cardBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(colors: [accentPurple.opacity(0.3), accentCyan.opacity(0.3)],
                                         startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1
                        )
                )
            }

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
            .disabled(state.isProcessing)
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

            // YouTube Download
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color.red)

                TextField("Paste YouTube URL here…", text: Binding(
                    get: { state.youtubeURL },
                    set: { state.youtubeURL = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

                Button(action: { actions.downloadYouTube(state.youtubeURL) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        Text("Download")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(Color.red)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(state.youtubeURL.isEmpty || state.isDownloading)
                .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }
            .padding(12)
            .background(cardBg)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )

            Text("Larger videos will take longer to process.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.35))
                .padding(.top, -4)
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
    var removeVideo: (Int) -> Void = { _ in }
    var downloadYouTube: (String) -> Void = { _ in }
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
            removeVideo:       { [weak self] idx in self?.removeLibraryVideo(idx) },
            downloadYouTube:   { [weak self] url in self?.downloadFromYouTube(url) },
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
        processAndImportVideo(sourceURL: url)
    }

    /// Probe video codec using ffprobe. Returns codec name (e.g. "hevc", "h264", "vp9", "av1").
    private static func probeVideoCodec(path: String) -> String {
        guard let ffprobe = findExecutable("ffprobe") else { return "" }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: ffprobe)
        task.arguments = ["-v", "quiet", "-select_streams", "v:0",
                          "-show_entries", "stream=codec_name",
                          "-of", "csv=p=0", path]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard let _ = try? task.run() else { return "" }
        task.waitUntilExit()
        guard let data = pipe.fileHandleForReading.readDataToEndOfFile() as Data?,
              let out = String(data: data, encoding: .utf8) else { return "" }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
    }

    /// Probe video duration in seconds using ffprobe.
    private static func probeVideoDuration(path: String) -> Double {
        guard let ffprobe = findExecutable("ffprobe") else { return 0 }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: ffprobe)
        task.arguments = ["-v", "quiet", "-show_entries", "format=duration",
                          "-of", "csv=p=0", path]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard let _ = try? task.run() else { return 0 }
        task.waitUntilExit()
        guard let data = pipe.fileHandleForReading.readDataToEndOfFile() as Data?,
              let out = String(data: data, encoding: .utf8) else { return 0 }
        return Double(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// Parse "time=HH:MM:SS.ms" from ffmpeg stderr output and return seconds.
    private static func parseFFmpegTime(_ text: String) -> Double? {
        // Look for time=HH:MM:SS.xx or time=SS.xx
        guard let range = text.range(of: "time=", options: .backwards) else { return nil }
        let after = String(text[range.upperBound...])
        let timeStr = after.components(separatedBy: " ").first ?? ""
        let parts = timeStr.components(separatedBy: ":")
        if parts.count == 3 {
            let h = Double(parts[0]) ?? 0
            let m = Double(parts[1]) ?? 0
            let s = Double(parts[2]) ?? 0
            return h * 3600 + m * 60 + s
        } else if let s = Double(parts[0]) {
            return s
        }
        return nil
    }

    private func processAndImportVideo(sourceURL: URL) {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let safeName = baseName.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destName = safeName + ".mov"
        let destPath = (VideoLibrary.shared.libraryPath as NSString).appendingPathComponent(destName)

        guard let ffmpeg = Self.findExecutable("ffmpeg") else {
            // No ffmpeg — just copy
            if !FileManager.default.fileExists(atPath: destPath) {
                try? FileManager.default.copyItem(at: sourceURL, to: URL(fileURLWithPath: destPath))
            }
            let finalURL = URL(fileURLWithPath: destPath)
            app?.changeVideo(url: finalURL)
            state.isDownloading = false
            state.downloadStatus = ""
            state.refresh()
            return
        }

        // Handoff from download UI to processing UI
        state.isDownloading = false
        state.isProcessing = true
        state.downloadProgress = 0
        state.processStatus = "Analyzing video…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tmpPath = destPath + ".tmp.mov"
            let fm = FileManager.default
            try? fm.removeItem(atPath: tmpPath)

            let sourceCodec = Self.probeVideoCodec(path: sourceURL.path)
            let totalDuration = Self.probeVideoDuration(path: sourceURL.path)

            var args: [String]
            if sourceCodec == "hevc" {
                // Already HEVC — just remux to .mov, keep audio
                DispatchQueue.main.async {
                    self?.state.processStatus = "Processing video for LivePaper…"
                }
                args = ["-i", sourceURL.path,
                        "-c", "copy",
                        "-movflags", "+faststart",
                        "-y", tmpPath]
            } else {
                // Transcode to HEVC via hardware VideoToolbox
                // Use 10-bit yuv420p10le and hvc1 tag to match Apple's
                // native aerial format (required for lock screen playback)
                DispatchQueue.main.async {
                    self?.state.processStatus = "Processing video for LivePaper…"
                }
                args = ["-i", sourceURL.path,
                        "-c:v", "hevc_videotoolbox",
                        "-b:v", "20M",
                        "-tag:v", "hvc1",
                        "-pix_fmt", "p010le",
                        "-c:a", "aac", "-b:a", "192k",
                        "-movflags", "+faststart",
                        "-y", tmpPath]
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: ffmpeg)
            task.arguments = args
            task.standardOutput = FileHandle.nullDevice

            // Parse stderr for progress
            let errPipe = Pipe()
            task.standardError = errPipe
            var stderrBuf = ""
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                stderrBuf += chunk
                if totalDuration > 0, let currentTime = Self.parseFFmpegTime(stderrBuf) {
                    let pct = min(currentTime / totalDuration, 0.99)
                    DispatchQueue.main.async {
                        self?.state.downloadProgress = pct
                        self?.state.processStatus = "Processing video for LivePaper… \(Int(pct * 100))%"
                    }
                    // Keep only last 500 chars to avoid memory growth
                    if stderrBuf.count > 500 {
                        stderrBuf = String(stderrBuf.suffix(300))
                    }
                }
            }

            var success = false
            do {
                try task.run()
                task.waitUntilExit()
                errPipe.fileHandleForReading.readabilityHandler = nil
                success = task.terminationStatus == 0
            } catch {
                errPipe.fileHandleForReading.readabilityHandler = nil
            }

            // Verify output file is valid
            if success {
                let attrs = try? fm.attributesOfItem(atPath: tmpPath)
                let size = attrs?[.size] as? Int ?? 0
                if size < 10000 { success = false }
            }

            if success {
                // Remove source if it's inside the library (in-place conversion)
                let srcInLibrary = sourceURL.path.hasPrefix(VideoLibrary.shared.libraryPath)
                if srcInLibrary && sourceURL.path != destPath {
                    try? fm.removeItem(at: sourceURL)
                }
                if fm.fileExists(atPath: destPath) { try? fm.removeItem(atPath: destPath) }
                try? fm.moveItem(atPath: tmpPath, toPath: destPath)
            } else {
                try? fm.removeItem(atPath: tmpPath)
                // Fallback: copy original if nothing at dest
                if !fm.fileExists(atPath: destPath) {
                    try? fm.copyItem(at: sourceURL, to: URL(fileURLWithPath: destPath))
                }
            }

            let finalURL = URL(fileURLWithPath: destPath)
            DispatchQueue.main.async {
                self?.state.isProcessing = false
                self?.state.downloadProgress = 0
                self?.state.processStatus = ""
                // Regenerate thumbnail for the processed video
                VideoLibrary.shared.invalidateThumbnail(for: finalURL)
                self?.app?.changeVideo(url: finalURL)
                self?.state.refresh()
            }
        }
    }

    private func selectLibraryVideo(_ index: Int) {
        let videos = state.libraryVideos
        guard index >= 0, index < videos.count else { return }
        let url = videos[index]

        // Check if video needs conversion to HEVC
        let codec = Self.probeVideoCodec(path: url.path)
        if codec != "hevc" && codec != "" {
            // Not HEVC — convert it in-place, then play
            processAndImportVideo(sourceURL: url)
        } else {
            app?.changeVideo(url: url)
            state.refresh()
        }
    }

    private func removeLibraryVideo(_ index: Int) {
        let videos = state.libraryVideos
        guard index >= 0, index < videos.count else { return }
        let url = videos[index]
        // If removing the currently playing video, switch to another first
        if url.path == app?.currentVideoURL.path {
            let others = videos.filter { $0.path != url.path }
            if let next = others.randomElement() {
                app?.changeVideo(url: next)
                LivePaperConfig.shared.wallpaperVideoPath = next.path
            } else {
                // No other videos — don't remove the last one
                return
            }
        }
        _ = VideoLibrary.shared.removeVideo(at: url)
        state.refresh()
    }

    private func downloadFromYouTube(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        // Basic URL validation
        guard urlString.contains("youtube.com") || urlString.contains("youtu.be") else {
            state.isDownloading = true
            state.downloadStatus = "❌ Invalid YouTube URL"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.state.isDownloading = false
                self?.state.downloadStatus = ""
            }
            return
        }
        guard let ytdlp = Self.findExecutable("yt-dlp") else {
            state.isDownloading = true
            state.downloadStatus = "❌ yt-dlp not found — run: brew install yt-dlp"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.state.isDownloading = false
                self?.state.downloadStatus = ""
            }
            return
        }

        state.isDownloading = true
        state.downloadProgress = 0
        state.downloadStatus = "Starting download…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            VideoLibrary.shared.ensureReady()
            let libraryPath = VideoLibrary.shared.libraryPath

            // Download best quality video+audio merged
            let task = Process()
            task.executableURL = URL(fileURLWithPath: ytdlp)
            task.arguments = [
                // Download BEST quality regardless of format (4K is usually webm/vp9)
                "-f", "bestvideo+bestaudio/best",
                // Output as mp4 first (yt-dlp merges here)
                "--merge-output-format", "mp4",
                "-o", (libraryPath as NSString).appendingPathComponent("%(title)s.%(ext)s"),
                "--no-playlist",
                "--concurrent-fragments", "8",
                "--progress",
                "--newline",
                urlString
            ]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            // Read output for progress updates
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("[download]") && trimmed.contains("%") {
                        // Parse percentage: "[download]  45.2% of ..."
                        let cleaned = trimmed.replacingOccurrences(of: "[download]", with: "").trimmingCharacters(in: .whitespaces)
                        if let pctEnd = cleaned.firstIndex(of: "%") {
                            let pctStr = cleaned[cleaned.startIndex..<pctEnd].trimmingCharacters(in: .whitespaces)
                            if let pct = Double(pctStr) {
                                DispatchQueue.main.async {
                                    self?.state.downloadProgress = pct / 100.0
                                    self?.state.downloadStatus = "Downloading… \(Int(pct))%"
                                }
                            }
                        }
                    } else if trimmed.contains("[Merger]") || trimmed.contains("[Merging]") {
                        DispatchQueue.main.async {
                            self?.state.downloadProgress = 0.95
                            self?.state.downloadStatus = "Merging audio and video…"
                        }
                    }
                }
            }

            do {
                try task.run()
                task.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                if task.terminationStatus == 0 {
                    // Find the newly downloaded file by modification time
                    let fm = FileManager.default
                    let allVideos = VideoLibrary.shared.videoFiles()
                    let newest = allVideos
                        .compactMap { url -> (URL, Date)? in
                            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                                  let mod = attrs[.modificationDate] as? Date else { return nil }
                            return (url, mod)
                        }
                        .sorted { $0.1 > $1.1 }
                        .first?.0

                    DispatchQueue.main.async {
                        self?.state.downloadProgress = 1.0
                        self?.state.downloadStatus = "Download complete! Processing…"
                        self?.state.youtubeURL = ""
                        // Keep isDownloading true — processAndImportVideo will clear it
                        // via isProcessing handoff

                        if let downloadedFile = newest {
                            self?.processAndImportVideo(sourceURL: downloadedFile)
                        } else {
                            self?.state.isDownloading = false
                            self?.state.downloadProgress = 0
                            self?.state.downloadStatus = ""
                            self?.state.refresh()
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.state.isDownloading = false
                        self?.state.downloadStatus = "Download failed"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.state.downloadStatus = ""
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.state.isDownloading = false
                    self?.state.downloadStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func findExecutable(_ name: String) -> String? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return nil
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
