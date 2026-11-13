import AppKit
import SwiftUI

@main
struct MacPowerSwitcherApp: App {
    @StateObject private var manager = SleepPreventer()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(manager: manager)
        } label: {
            Image(systemName: manager.isEnabled ? "bolt.fill" : "bolt.slash")
                .symbolRenderingMode(.hierarchical)
        }

        Window("Settings", id: "settings") {
            SettingsView(manager: manager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 440, height: 520)

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
        if manager.isEnabled {
            Text(manager.menuStatus)
            Divider()
        }

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

            Text("Turn wake mode on and the Mac stays awake while the lid is open. After you close the lid, it sleeps when the time you set runs out.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                bullet(
                    "Turn on wake up / Turn off wake up",
                    "Turns wake mode on or off. While it is on and the lid is open, the Mac stays awake. It does not turn itself off during use."
                )
                bullet(
                    "Sleep after closing the lid",
                    wakeTimeoutDetail
                )
                bullet(
                    "Menu bar",
                    "The menu bar shows only the lightning bolt. The sleep time does not count down there, and it is not shown while you are using the Mac."
                )
                bullet(
                    "Power source",
                    "Only applies on AC power. On battery, the Mac still sleeps normally."
                )
                bullet(
                    "Low battery",
                    "If the lid is closed, the battery is at \(settings.minPowerPercent)% or below, and it is not charging, wake mode turns off by itself so the Mac can sleep. That path does not ask for Touch ID."
                )
                bullet(
                    "Opening the lid",
                    "Opening the lid cancels the sleep time and keeps the Mac awake. Wake mode stays on."
                )
                bullet(
                    "Closing the lid",
                    "Closing the lid starts the full sleep time. A later close starts it over from the beginning."
                )
                bullet(
                    "Settings",
                    "Open Settings from the menu to change how long the Mac stays awake after the lid closes, and the minimum battery. Values are stored in ~/.mac-power-switcher/settings.json. If that file is missing, the app uses the defaults (sleep 30 minutes after the lid closes, 10% battery)."
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
        return "Version \(version ?? "1.2.0")"
    }

    private var wakeTimeoutDetail: String {
        guard let minutes = settings.autoDisableMinutes else {
            return "With the lid closed, the Mac stays awake until you turn wake mode off, or until the battery reaches the minimum level."
        }
        if minutes == 1 {
            return "After the lid closes, the Mac sleeps 1 minute later. Opening the lid cancels that and keeps the Mac awake."
        }
        return "After the lid closes, the Mac sleeps \(minutes) minutes later. Opening the lid cancels that and keeps the Mac awake."
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
