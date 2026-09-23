import AppKit
import Foundation
import notify

@MainActor
final class SleepPreventer: ObservableObject {
    let settingsStore = AppSettingsStore()

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var autoDisableReason: AutoDisableReason?

    private var watchTimer: Timer?
    private var autoOffTimer: Timer?
    private var lidNotifyToken: Int32 = 0
    private var enabledAt: Date?
    private var previousLidClosed: Bool = false

    var minPowerPercent: Int { settingsStore.settings.minPowerPercent }

    enum AutoDisableReason {
        case lowBattery
        case timeout
        case lidOpened
    }

    init() {
        refresh()
        if isEnabled {
            enabledAt = settingsStore.loadWakeState().enabledAt ?? Date()
            persistWakeState()
            startWatching()
        }
    }

    func refresh() {
        isEnabled = Self.readSleepDisabled()
    }

    func settingsDidChange() {
        objectWillChange.send()
        guard isEnabled else { return }
        scheduleAutoOffTimer()
        autoDisableIfNeeded()
        autoDisableIfTimedOut()
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
                autoDisableReason = nil
                if enabled {
                    enabledAt = Date()
                    persistWakeState()
                    startWatching()
                } else {
                    clearWakeState()
                    stopWatching()
                }
            } catch {
                refresh()
                NSSound.beep()
            }
        }
    }

    var timeoutMenuText: String {
        guard let minutes = settingsStore.settings.autoDisableMinutes else {
            return "Wake timeout: infinite"
        }
        if minutes == 1 {
            return "Turns off automatically after 1 minute"
        }
        return "Turns off automatically after \(minutes) minutes"
    }

    private func autoDisableIfNeeded() {
        guard isEnabled, !isBusy else { return }
        guard PowerStatus.isLidClosed() else { return }
        guard let battery = PowerStatus.battery() else { return }
        guard battery.percent <= minPowerPercent, !battery.isCharging else { return }
        performAutoDisable(reason: .lowBattery)
    }

    private func autoDisableIfLidOpened() {
        guard isEnabled, !isBusy else { return }
        guard settingsStore.settings.disableOnLidOpen else { return }
        let lidClosed = PowerStatus.isLidClosed()
        defer { previousLidClosed = lidClosed }
        guard previousLidClosed, !lidClosed else { return }
        performAutoDisable(reason: .lidOpened)
    }

    private func autoDisableIfTimedOut() {
        guard isEnabled, !isBusy else { return }
        guard let minutes = settingsStore.settings.autoDisableMinutes, let enabledAt else { return }
        let deadline = enabledAt.addingTimeInterval(TimeInterval(minutes * 60))
        guard Date() >= deadline else { return }
        performAutoDisable(reason: .timeout)
    }

    private func performAutoDisable(reason: AutoDisableReason) {
        guard isEnabled, !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.setSleepDisabled(false)
                isEnabled = false
                autoDisableReason = reason
                clearWakeState()
                stopWatching()
                if PowerStatus.isLidClosed(), !PowerStatus.hasExternalDisplay() {
                    PowerStatus.sleepNow()
                }
            } catch {
                refresh()
            }
        }
    }

    private func startWatching() {
        stopWatching()
        previousLidClosed = PowerStatus.isLidClosed()
        autoDisableIfNeeded()
        autoDisableIfTimedOut()
        scheduleAutoOffTimer()

        watchTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autoDisableIfNeeded()
                self?.autoDisableIfTimedOut()
                self?.autoDisableIfLidOpened()
            }
        }

        notify_register_dispatch(
            "com.apple.iokit.powermanagement.clamshellstate",
            &lidNotifyToken,
            DispatchQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.autoDisableIfNeeded()
                self?.autoDisableIfLidOpened()
            }
        }
    }

    private func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        autoOffTimer?.invalidate()
        autoOffTimer = nil
        if lidNotifyToken != 0 {
            notify_cancel(lidNotifyToken)
            lidNotifyToken = 0
        }
    }

    private func scheduleAutoOffTimer() {
        autoOffTimer?.invalidate()
        autoOffTimer = nil
        guard isEnabled else { return }
        guard let minutes = settingsStore.settings.autoDisableMinutes, let enabledAt else { return }
        let remaining = enabledAt.addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSinceNow
        if remaining <= 0 {
            autoDisableIfTimedOut()
            return
        }
        autoOffTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.autoDisableIfTimedOut()
            }
        }
    }

    private func persistWakeState() {
        settingsStore.saveWakeState(WakeState(enabledAt: enabledAt))
    }

    private func clearWakeState() {
        enabledAt = nil
        settingsStore.saveWakeState(WakeState(enabledAt: nil))
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
