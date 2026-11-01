import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: SleepPreventer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var timeoutChoice: WakeTimeoutChoice = .minutes(30)
    @State private var customMinutes: Int = 30
    @State private var minPowerPercent: Int = 10
    @State private var disableOnLidOpen: Bool = false
    @State private var extendOnLidClose: Bool = true
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Wake timeout")
                    .font(.headline)
                Text("Automatically turn off sleep prevention after this time. While the lid is open, the time left appears beside the menu bar icon. Infinite keeps it on until you turn it off, or until the battery is low.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Wake timeout", selection: $timeoutChoice) {
                    Text("10 minutes").tag(WakeTimeoutChoice.minutes(10))
                    Text("15 minutes").tag(WakeTimeoutChoice.minutes(15))
                    Text("30 minutes").tag(WakeTimeoutChoice.minutes(30))
                    Text("60 minutes").tag(WakeTimeoutChoice.minutes(60))
                    Text("Custom").tag(WakeTimeoutChoice.custom)
                    Text("Infinite").tag(WakeTimeoutChoice.infinite)
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
                Text("If the lid is closed, the battery is at or below this level, and it is not charging, sleep prevention turns off so the Mac can sleep.")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Lid")
                    .font(.headline)
                Text("Sleep prevention stays on until you turn it off. You can also turn it off when the lid opens, and restart the wake timeout when the lid closes.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Turn off when the lid opens", isOn: $disableOnLidOpen)
                    .toggleStyle(.switch)
                Text("Off by default. Turn this on if opening the lid should restore normal sleep immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Restart the timer when the lid closes", isOn: $extendOnLidClose)
                    .toggleStyle(.switch)
                Text("On by default. Closing the lid starts the wake timeout over. A 15-minute timer with 2 minutes left becomes 15 minutes again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        disableOnLidOpen = settings.disableOnLidOpen
        extendOnLidClose = settings.extendOnLidClose
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
            minPowerPercent: minPowerPercent,
            disableOnLidOpen: disableOnLidOpen,
            extendOnLidClose: extendOnLidClose
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
