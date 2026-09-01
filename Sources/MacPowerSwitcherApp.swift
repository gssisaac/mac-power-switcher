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

        Window("About Mac Power Switcher", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 440, height: 460)
    }
}

private struct MenuContent: View {
    @ObservedObject var manager: SleepPreventer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(
            manager.isEnabled
                ? "Currently: sleep is prevented (lid close stays awake)"
                : "Currently: sleep is allowed (normal)"
        )

        if manager.didAutoDisable {
            Text("Auto-disabled: battery was low with the lid closed")
        }

        Text("Auto-disables at \(SleepPreventer.lowBatteryPercent)% if the lid is closed and not charging")

        Divider()

        Button("Prevent Sleep When Lid Closed") {
            manager.setEnabled(true)
        }
        .disabled(manager.isEnabled || manager.isBusy)

        Button("Allow Sleep (Restore Normal)") {
            manager.setEnabled(false)
        }
        .disabled(!manager.isEnabled || manager.isBusy)

        Divider()

        Button("About Mac Power Switcher") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
    }
}

private struct AboutView: View {
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
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("This menu bar app keeps your Mac awake when you close the lid, as long as it is plugged into a charger.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                bullet(
                    "Prevent Sleep When Lid Closed",
                    "Turns sleep prevention on. Closing the lid will not put the Mac to sleep."
                )
                bullet(
                    "Allow Sleep (Restore Normal)",
                    "Turns sleep prevention off. The Mac sleeps the usual way again."
                )
                bullet(
                    "Power source",
                    "Only applies on AC power. On battery, the Mac still sleeps normally."
                )
                bullet(
                    "Low battery",
                    "If the lid is closed, the battery is at \(SleepPreventer.lowBatteryPercent)% or below, and it is not charging, sleep prevention turns off by itself so the Mac can sleep. That path uses the approval you already gave when you turned prevention on — no Touch ID with the lid closed."
                )
                bullet(
                    "Authentication",
                    "Manually changing the setting still requires Touch ID or your Mac password. The first time, macOS may also ask for an administrator password to install a helper."
                )
            }

            Text("It is a thin switch for the system setting `pmset -c disablesleep`.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 440)
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
