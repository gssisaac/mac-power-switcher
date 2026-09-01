import Foundation

enum PrivilegedHelper {
    static let helperPath = "/Library/MacPowerSwitcher/pmset-helper"
    private static let sudoersPath = "/etc/sudoers.d/mac-power-switcher"

    private static let helperSource = """
    #!/bin/bash
    set -euo pipefail
    case "${1:-}" in
      0|1) exec /usr/bin/pmset -c disablesleep "$1" ;;
      *) exit 2 ;;
    esac
    """

    static func ensureInstalled() throws {
        if canRunWithoutPassword() { return }
        try install()
        guard canRunWithoutPassword() else { throw HelperError.installFailed }
    }

    static func setSleepDisabled(_ enabled: Bool) throws {
        let value = enabled ? "1" : "0"
        let code = runSudo(helperArgs: [value])
        guard code == 0 else { throw HelperError.pmsetFailed(code) }
    }

    /// sudo auth OK + helper reachable → exit 2 (usage). sudo needs password → exit 1.
    private static func canRunWithoutPassword() -> Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
            && runSudo(helperArgs: []) == 2
    }

    private static func install() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mac-power-switcher-pmset-helper")
        try helperSource.write(to: tempURL, atomically: true, encoding: .utf8)

        let sudoersLine = "%admin ALL=(root) NOPASSWD: \(helperPath)"
        let tempSudoers = FileManager.default.temporaryDirectory
            .appendingPathComponent("mac-power-switcher-sudoers")
        try (sudoersLine + "\n").write(to: tempSudoers, atomically: true, encoding: .utf8)

        let script = """
        do shell script "mkdir -p /Library/MacPowerSwitcher && cp '\(tempURL.path)' '\(helperPath)' && chmod 755 '\(helperPath)' && chown root:wheel '\(helperPath)' && cp '\(tempSudoers.path)' '\(sudoersPath)' && chmod 440 '\(sudoersPath)' && chown root:wheel '\(sudoersPath)' && visudo -cf '\(sudoersPath)'" with administrator privileges
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw HelperError.installFailed
        }
        appleScript.executeAndReturnError(&error)
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: tempSudoers)
        if error != nil { throw HelperError.installFailed }
    }

    private static func runSudo(helperArgs: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath] + helperArgs
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    enum HelperError: Error {
        case installFailed
        case pmsetFailed(Int32)
    }
}
