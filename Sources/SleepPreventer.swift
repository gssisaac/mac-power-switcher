import AppKit
import Foundation
import notify

/// Wake mode stays on while the lid is open. The chosen duration does not
/// count, and is not shown, until the lid closes. Opening the lid cancels
/// it. When the time runs out with the lid still closed, the Mac sleeps and
/// wake mode stays on, so the next time the lid opens the timer is reset.
@MainActor
final class SleepPreventer: ObservableObject {
    let settingsStore = AppSettingsStore()

    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false
    @Published private(set) var lidClosed = false

    private var watchTimer: Timer?
    private var autoOffTimer: Timer?
    private var lidNotifyToken: Int32 = 0
    private var wakeObserver: NSObjectProtocol?
    private var powerActivity: NSObjectProtocol?
    private var lidClosedAt: Date?
    private var previousLidClosed = false
    private var hasConfirmedAuth = false

    var minPowerPercent: Int { settingsStore.settings.minPowerPercent }

    var menuStatus: String {
        guard isEnabled else { return "Off" }
        if !lidClosed {
            return "On. The Mac stays awake while the lid is open."
        }
        if settingsStore.settings.autoDisableMinutes == nil {
            return "On. The lid is closed. The Mac stays awake."
        }
        return "On. The lid is closed. The Mac sleeps when the time is up."
    }

    init() {
        let pmsetOn = Self.readSleepDisabled()
        let state = settingsStore.loadWakeState()
        if let mode = state.modeEnabled {
            isEnabled = mode
            lidClosedAt = state.lidClosedAt
            if !mode && pmsetOn {
                Task { try? PrivilegedHelper.setSleepDisabled(false) }
            }
        } else {
            isEnabled = pmsetOn
            if pmsetOn {
                persistWakeState()
            }
        }
        if isEnabled {
            startWatching()
        }
    }

    func settingsDidChange() {
        objectWillChange.send()
        guard isEnabled else { return }
        reconcilePowerState()
    }

    func setEnabled(_ enabled: Bool) {
        guard !isBusy, isEnabled != enabled else { return }
        isBusy = true

        Task {
            do {
                try PrivilegedHelper.ensureInstalled()
                if !hasConfirmedAuth {
                    try await BiometricAuth.confirm()
                    hasConfirmedAuth = true
                }
                try PrivilegedHelper.setSleepDisabled(enabled)
                isEnabled = enabled
                lidClosedAt = nil
                persistWakeState()
            } catch {
                isEnabled = Self.readSleepDisabled()
                NSSound.beep()
            }
            isBusy = false
            if isEnabled {
                startWatching()
            } else {
                stopWatching()
            }
        }
    }

    private func reconcilePowerState() {
        let closed = PowerStatus.isLidClosed()
        if lidClosed != closed {
            lidClosed = closed
        }

        // A toggle or sleep request is in flight. Leave the previous lid
        // sample in place so the transition is still visible when it finishes.
        guard isEnabled, !isBusy else { return }

        let wasClosed = previousLidClosed
        previousLidClosed = closed

        if !closed {
            if wasClosed || lidClosedAt != nil {
                setLidClosedAt(nil)
                autoOffTimer?.invalidate()
                autoOffTimer = nil
            }
            beginPowerActivity()
            ensureSleepPrevention(enabled: true)
            return
        }

        if !wasClosed || lidClosedAt == nil {
            setLidClosedAt(Date())
        }

        if shouldForceOffForLowBattery() {
            disableForLowBattery()
            return
        }

        if closedLidDeadlinePassed() {
            sleepForClosedLidTimeout()
            return
        }

        beginPowerActivity()
        ensureSleepPrevention(enabled: true)
        scheduleAutoOffTimer()
    }

    private func shouldForceOffForLowBattery() -> Bool {
        guard lidClosed else { return false }
        guard let battery = PowerStatus.battery() else { return false }
        return battery.percent <= minPowerPercent && !battery.isCharging
    }

    private func closedLidDeadline() -> Date? {
        guard let minutes = settingsStore.settings.autoDisableMinutes, let lidClosedAt else {
            return nil
        }
        return lidClosedAt.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func closedLidDeadlinePassed(now: Date = Date()) -> Bool {
        guard let deadline = closedLidDeadline() else { return false }
        return now >= deadline
    }

    private func sleepForClosedLidTimeout() {
        guard isEnabled else { return }
        guard PowerStatus.isLidClosed() else { return }
        guard closedLidDeadlinePassed() else { return }
        guard !isBusy else {
            scheduleSleepRetry()
            return
        }

        isBusy = true
        endPowerActivity()
        Task {
            var resumeAwake = false
            do {
                try PrivilegedHelper.setSleepDisabled(false)
                try await Task.sleep(nanoseconds: 500_000_000)
                if PowerStatus.isLidClosed(), closedLidDeadlinePassed() {
                    PowerStatus.sleepNow()
                } else {
                    beginPowerActivity()
                    try PrivilegedHelper.setSleepDisabled(true)
                    resumeAwake = true
                }
            } catch {
                beginPowerActivity()
                resumeAwake = true
            }
            isBusy = false
            if resumeAwake {
                reconcilePowerState()
            }
        }
    }

    private func disableForLowBattery() {
        guard isEnabled, !isBusy else { return }
        isBusy = true
        endPowerActivity()
        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.setSleepDisabled(false)
                isEnabled = false
                lidClosedAt = nil
                persistWakeState()
                stopWatching()
                if PowerStatus.isLidClosed(), !PowerStatus.hasExternalDisplay() {
                    PowerStatus.sleepNow()
                }
            } catch {
                beginPowerActivity()
            }
        }
    }

    private func ensureSleepPrevention(enabled: Bool) {
        guard !isBusy else { return }
        guard Self.readSleepDisabled() != enabled else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try PrivilegedHelper.setSleepDisabled(enabled)
            } catch {
                // The next lid or wake pass tries again.
            }
        }
    }

    private func startWatching() {
        stopWatching()
        beginPowerActivity()
        let closed = PowerStatus.isLidClosed()
        previousLidClosed = closed
        lidClosed = closed
        installMonitors()
        reconcilePowerState()
    }

    private func installMonitors() {
        let watch = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reconcilePowerState()
            }
        }
        RunLoop.main.add(watch, forMode: .common)
        watchTimer = watch

        notify_register_dispatch(
            "com.apple.iokit.powermanagement.clamshellstate",
            &lidNotifyToken,
            DispatchQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcilePowerState()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcilePowerState()
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
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        endPowerActivity()
    }

    private func scheduleAutoOffTimer() {
        autoOffTimer?.invalidate()
        autoOffTimer = nil
        guard isEnabled, lidClosed, let deadline = closedLidDeadline() else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            sleepForClosedLidTimeout()
            return
        }
        let timer = Timer(timeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sleepForClosedLidTimeout()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoOffTimer = timer
    }

    private func scheduleSleepRetry() {
        autoOffTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sleepForClosedLidTimeout()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoOffTimer = timer
    }

    private func beginPowerActivity() {
        guard powerActivity == nil else { return }
        powerActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Mac Power Switcher is keeping this Mac awake"
        )
    }

    private func endPowerActivity() {
        guard let powerActivity else { return }
        ProcessInfo.processInfo.endActivity(powerActivity)
        self.powerActivity = nil
    }

    private func setLidClosedAt(_ date: Date?) {
        guard lidClosedAt != date else { return }
        lidClosedAt = date
        persistWakeState()
    }

    private func persistWakeState() {
        settingsStore.saveWakeState(WakeState(modeEnabled: isEnabled, lidClosedAt: lidClosedAt))
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
