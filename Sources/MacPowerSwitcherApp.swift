import AppKit
import SwiftUI

@main
struct MacPowerSwitcherApp: App {
    @StateObject private var manager = SleepPreventer()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(manager: manager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: manager.isEnabled ? "bolt.fill" : "bolt.slash")
                    .symbolRenderingMode(.hierarchical)
                if let trayTimeText = manager.trayTimeText {
                    Text(trayTimeText)
                        .font(.system(size: 13).monospacedDigit())
                        .fixedSize()
                }
            }
        }

        Window("Settings", id: "settings") {
            SettingsView(manager: manager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 440, height: 680)

        Window("About Mac Power Switcher", id: "about") {
            AboutView(settings: manager.settingsStore.settings)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 440, height: 620)
    }
}

private struct MenuContent: View {
    @ObservedObject var manager: SleepPreventer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(manager.isEnabled ? "Turn off wake up" : "Turn on wake up") {
            manager.setEnabled(!manager.isEnabled)
        }
        .disabled(manager.isBusy)

        Divider()

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

private struct AboutView: View {
    var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Power Switcher")
                        .font(.title2.bold())
                    Text(versionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("This menu bar app keeps your Mac awake when you close the lid, as long as it is plugged into a charger.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                bullet(
                    "Turn on wake up / Turn off wake up",
                    "Turns sleep prevention on or off. It stays on until you turn it off, unless a wake timeout or the lid option below says otherwise."
                )
                bullet(
                    "Wake timeout",
                    wakeTimeoutDetail
                )
                bullet(
                    "Time in the menu bar",
                    "While the lid is open and a wake timeout is set, the time left appears to the right of the lightning bolt as hh:mm, such as 00:14 or 01:05."
                )
                bullet(
                    "Power source",
                    "Only applies on AC power. On battery, the Mac still sleeps normally."
                )
                bullet(
                    "Low battery",
                    "If the lid is closed, the battery is at \(settings.minPowerPercent)% or below, and it is not charging, sleep prevention turns off by itself so the Mac can sleep. That path does not ask for Touch ID."
                )
                bullet(
                    "Lid opens",
                    settings.disableOnLidOpen
                        ? "When you open the lid again, sleep prevention turns off by itself so the Mac returns to normal."
                        : "Sleep prevention stays on after you open the lid. Turn it off yourself with Turn off wake up, or wait for the wake timeout."
                )
                bullet(
                    "Lid closes",
                    settings.extendOnLidClose
                        ? "Closing the lid starts the wake timeout over. A 15-minute timer with 2 minutes left becomes 15 minutes again."
                        : "Closing the lid does not change the wake timeout. The countdown keeps running."
                )
                bullet(
                    "Settings",
                    "Open Settings from the menu to change the wake timeout, minimum battery, and lid behavior. Values are stored in ~/.mac-power-switcher/settings.json. If that file is missing, the app uses the defaults (30-minute timeout, 10% battery, stay on when the lid opens, restart the timer when the lid closes)."
                )
                bullet(
                    "Authentication",
                    "The first time you turn this on or off after the app launches, macOS asks for Touch ID or your password. Later changes in that session do not ask again. The first time, macOS may also ask for an administrator password to install a helper."
                )
            }

            Text("It is a thin switch for the system setting `pmset -c disablesleep`.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 440)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "Version \(version ?? "1.1.0")"
    }

    private var wakeTimeoutDetail: String {
        guard let minutes = settings.autoDisableMinutes else {
            return "Sleep prevention stays on until you turn it off, or until the battery reaches the minimum level."
        }
        if minutes == 1 {
            return "Sleep prevention turns off by itself after 1 minute."
        }
        return "Sleep prevention turns off by itself after \(minutes) minutes."
    }

    private func bullet(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
