import AppKit
import Foundation
import notify

@MainActor
final class SleepPreventer: ObservableObject {
    let settingsStore = AppSettingsStore()

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var autoDisableReason: AutoDisableReason?
    /// Minutes or `h:mm` left until the wake timeout, shown beside the tray icon while the lid is open.
    @Published private(set) var trayTimeText: String?

    private var watchTimer: Timer?
    private var autoOffTimer: Timer?
    private var displayTimer: Timer?
    private var lidNotifyToken: Int32 = 0
    private var enabledAt: Date?
    private var previousLidClosed: Bool = false
    private var hasConfirmedAuth = false

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
        guard isEnabled else {
            updateTrayTime()
            return
        }
        scheduleAutoOffTimer()
        handleLidChange()
        autoDisableIfTimedOut()
        updateTrayTime()
    }

    func setEnabled(_ enabled: Bool) {
        guard !isBusy, isEnabled != enabled else { return }
        isBusy = true

        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.ensureInstalled()
                if !hasConfirmedAuth {
                    try await BiometricAuth.confirm()
                    hasConfirmedAuth = true
                }
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

    /// `h:mm` when an hour or more remains, otherwise just the minute count, rounded up.
    static func formatRemaining(_ remaining: TimeInterval) -> String? {
        guard remaining > 0 else { return nil }
        let seconds = Int(remaining.rounded(.up))
        guard seconds > 0 else { return nil }
        let minutesRoundedUp = (seconds + 59) / 60
        let hours = minutesRoundedUp / 60
        let minutes = minutesRoundedUp % 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        return String(minutesRoundedUp)
    }

    private func autoDisableIfNeeded() {
        guard isEnabled, !isBusy else { return }
        guard PowerStatus.isLidClosed() else { return }
        guard let battery = PowerStatus.battery() else { return }
        guard battery.percent <= minPowerPercent, !battery.isCharging else { return }
        performAutoDisable(reason: .lowBattery)
    }

    private func handleLidChange() {
        let lidClosed = PowerStatus.isLidClosed()
        let wasClosed = previousLidClosed
        previousLidClosed = lidClosed

        if wasClosed && !lidClosed && settingsStore.settings.disableOnLidOpen {
            performAutoDisable(reason: .lidOpened)
            return
        }

        if !wasClosed && lidClosed {
            restartWakeTimerIfExtending()
        }

        autoDisableIfNeeded()
        updateTrayTime()
    }

    private func restartWakeTimerIfExtending() {
        guard isEnabled, !isBusy else { return }
        guard settingsStore.settings.extendOnLidClose else { return }
        guard settingsStore.settings.autoDisableMinutes != nil else { return }
        enabledAt = Date()
        persistWakeState()
        scheduleAutoOffTimer()
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
        updateTrayTime()

        watchTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleLidChange()
                self?.autoDisableIfTimedOut()
            }
        }

        let display = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTrayTime()
            }
        }
        RunLoop.main.add(display, forMode: .common)
        displayTimer = display

        notify_register_dispatch(
            "com.apple.iokit.powermanagement.clamshellstate",
            &lidNotifyToken,
            DispatchQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleLidChange()
            }
        }
    }

    private func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        autoOffTimer?.invalidate()
        autoOffTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
        trayTimeText = nil
        if lidNotifyToken != 0 {
            notify_cancel(lidNotifyToken)
            lidNotifyToken = 0
        }
    }

    private func updateTrayTime() {
        let next = currentTrayTimeText()
        if trayTimeText != next {
            trayTimeText = next
        }
    }

    private func currentTrayTimeText() -> String? {
        guard isEnabled, !PowerStatus.isLidClosed() else { return nil }
        guard let minutes = settingsStore.settings.autoDisableMinutes, let enabledAt else { return nil }
        let remaining = enabledAt.addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSinceNow
        return Self.formatRemaining(remaining)
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
