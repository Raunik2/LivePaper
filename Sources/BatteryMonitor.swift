// LivePaper – Battery Monitor
// Detects AC vs battery power and triggers battery-saving mode.

import Foundation
import IOKit

class BatteryMonitor {
    private weak var app: LivePaperApp?
    private var timer: Timer?
    private(set) var isOnBattery = false

    init(app: LivePaperApp) {
        self.app = app
        isOnBattery = Self.checkOnBattery()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 10
        if isOnBattery { app.enterBatteryMode() }
    }

    static func checkOnBattery() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return false }

        let externalConnected = dict["ExternalConnected"] as? Bool ?? true
        return !externalConnected
    }

    private func tick() {
        let was = isOnBattery
        isOnBattery = Self.checkOnBattery()
        if was != isOnBattery {
            NSLog("LivePaper: Power source changed — %@", isOnBattery ? "battery" : "AC")
            if isOnBattery { app?.enterBatteryMode() }
            else { app?.exitBatteryMode() }
        }
    }

    func stop() { timer?.invalidate() }
}
