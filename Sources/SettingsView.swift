import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: SleepPreventer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var timeoutChoice: WakeTimeoutChoice = .minutes(30)
    @State private var customMinutes: Int = 30
    @State private var minPowerPercent: Int = 10
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Sleep after closing the lid")
                    .font(.headline)
                Text("While the lid is open, the Mac stays awake. This time does not count down, and it does not appear in the menu bar. Closing the lid starts it. When the time is up, the Mac sleeps. Opening the lid cancels it. Closing the lid again starts the full time over. Never keeps the Mac awake with the lid closed until you turn wake mode off.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Sleep after closing the lid", selection: $timeoutChoice) {
                    Text("10 minutes").tag(WakeTimeoutChoice.minutes(10))
                    Text("15 minutes").tag(WakeTimeoutChoice.minutes(15))
                    Text("30 minutes").tag(WakeTimeoutChoice.minutes(30))
                    Text("60 minutes").tag(WakeTimeoutChoice.minutes(60))
                    Text("Custom").tag(WakeTimeoutChoice.custom)
                    Text("Never").tag(WakeTimeoutChoice.infinite)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if timeoutChoice == .custom {
                    HStack(spacing: 8) {
                        Text("Minutes")
                        TextField("Minutes", value: $customMinutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                        Stepper("Minutes", value: $customMinutes, in: AppSettings.customMinutesRange)
                            .labelsHidden()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum battery")
                    .font(.headline)
                Text("If the lid is closed, the battery is at or below this level, and it is not charging, wake mode turns off so the Mac can sleep.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text("Turn off at")
                    TextField("Percent", value: $minPowerPercent, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                    Text("%")
                    Stepper("Percent", value: $minPowerPercent, in: AppSettings.minPowerRange)
                        .labelsHidden()
                }
            }

            if let saveError {
                Text(saveError)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Text("Saved to ~/.mac-power-switcher/settings.json")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("About") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "about")
                }
                Spacer()
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear(perform: loadFromStore)
    }

    private var canSave: Bool {
        let timeoutOK = timeoutChoice != .custom || AppSettings.customMinutesRange.contains(customMinutes)
        return timeoutOK && AppSettings.minPowerRange.contains(minPowerPercent)
    }

    private func loadFromStore() {
        let settings = manager.settingsStore.settings
        timeoutChoice = WakeTimeoutChoice.from(storedMinutes: settings.autoDisableMinutes)
        customMinutes = settings.autoDisableMinutes ?? 30
        minPowerPercent = settings.minPowerPercent
        saveError = nil
    }

    private func save() {
        guard canSave else { return }
        let minutes: Int?
        switch timeoutChoice {
        case .minutes(let value):
            minutes = value
        case .custom:
            minutes = customMinutes
        case .infinite:
            minutes = nil
        }

        manager.settingsStore.settings = AppSettings(
            autoDisableMinutes: minutes,
            minPowerPercent: minPowerPercent
        )
        do {
            try manager.settingsStore.save()
            manager.settingsDidChange()
            closeWindow()
        } catch {
            saveError = "Could not save settings."
            NSSound.beep()
        }
    }

    private func closeWindow() {
        dismiss()
        NSApp.windows.first { $0.title == "Settings" }?.close()
    }
}
