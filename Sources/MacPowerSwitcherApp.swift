import SwiftUI

@main
struct MacPowerSwitcherApp: App {
    @StateObject private var manager = SleepPreventer()

    var body: some Scene {
        MenuBarExtra {
            Button("Enable") {
                manager.setEnabled(true)
            }
            .disabled(manager.isEnabled || manager.isBusy)

            Button("Disable") {
                manager.setEnabled(false)
            }
            .disabled(!manager.isEnabled || manager.isBusy)
        } label: {
            Image(systemName: manager.isEnabled ? "bolt.fill" : "bolt.slash")
                .symbolRenderingMode(.hierarchical)
        }
    }
}
