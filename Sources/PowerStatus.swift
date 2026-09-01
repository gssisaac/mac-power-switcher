import AppKit
import CoreGraphics
import Foundation
import IOKit
import IOKit.ps

enum PowerStatus {
    struct Battery {
        var percent: Int
        var isCharging: Bool
    }

    static func battery() -> Battery? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = info[kIOPSTypeKey as String] as? String
            guard type == (kIOPSInternalBatteryType as String) else { continue }

            let current = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey as String] as? Int ?? 0
            let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            let isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
            return Battery(percent: percent, isCharging: isCharging)
        }
        return nil
    }

    static func isLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return false
        }
        return (property as? Bool) == true
    }

    static func hasExternalDisplay() -> Bool {
        NSScreen.screens.contains { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
        }
    }

    static func sleepNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }
}
