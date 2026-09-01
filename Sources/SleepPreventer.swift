import AppKit
import Foundation
import notify

@MainActor
final class SleepPreventer: ObservableObject {
    static let lowBatteryPercent = 10

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var didAutoDisable = false

    private var watchTimer: Timer?
    private var lidNotifyToken: Int32 = 0

    init() {
        refresh()
        if isEnabled {
            startWatching()
        }
    }

    func refresh() {
        isEnabled = Self.readSleepDisabled()
    }

    func setEnabled(_ enabled: Bool) {
        guard !isBusy, isEnabled != enabled else { return }
        isBusy = true

        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.ensureInstalled()
                try await BiometricAuth.confirm()
                try PrivilegedHelper.setSleepDisabled(enabled)
                isEnabled = enabled
                didAutoDisable = false
                if enabled {
                    startWatching()
                } else {
                    stopWatching()
                }
            } catch {
                refresh()
                NSSound.beep()
            }
        }
    }

    private func autoDisableIfNeeded() {
        guard isEnabled, !isBusy else { return }
        guard PowerStatus.isLidClosed() else { return }
        guard let battery = PowerStatus.battery() else { return }
        guard battery.percent <= Self.lowBatteryPercent, !battery.isCharging else { return }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.setSleepDisabled(false)
                isEnabled = false
                didAutoDisable = true
                stopWatching()
                if !PowerStatus.hasExternalDisplay() {
                    PowerStatus.sleepNow()
                }
            } catch {
                refresh()
            }
        }
    }

    private func startWatching() {
        stopWatching()
        autoDisableIfNeeded()

        watchTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autoDisableIfNeeded()
            }
        }

        notify_register_dispatch(
            "com.apple.iokit.powermanagement.clamshellstate",
            &lidNotifyToken,
            DispatchQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.autoDisableIfNeeded()
            }
        }
    }

    private func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        if lidNotifyToken != 0 {
            notify_cancel(lidNotifyToken)
            lidNotifyToken = 0
        }
    }

    private static func readSleepDisabled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output
                .split(whereSeparator: \.isNewline)
                .contains { line in
                    let parts = line.split(whereSeparator: \.isWhitespace)
                    return parts.count >= 2
                        && parts[0].caseInsensitiveCompare("SleepDisabled") == .orderedSame
                        && parts[1] == "1"
                }
        } catch {
            return false
        }
    }
}
