import AppKit
import Foundation

@MainActor
final class SleepPreventer: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isBusy = false

    init() {
        refresh()
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
            } catch {
                refresh()
                NSSound.beep()
            }
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
