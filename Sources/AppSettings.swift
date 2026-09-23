import Foundation

struct AppSettings: Equatable {
    /// Minutes until wake mode turns off. `nil` means infinite.
    var autoDisableMinutes: Int?
    /// Turn off wake mode at or below this battery percent when the lid is closed and not charging.
    var minPowerPercent: Int
    /// When true, sleep prevention turns off automatically when the lid is opened again.
    var disableOnLidOpen: Bool

    static let `default` = AppSettings(autoDisableMinutes: 30, minPowerPercent: 10, disableOnLidOpen: true)
    static let timeoutPresets = [10, 15, 30, 60]
    static let minPowerRange = 1...100
    static let customMinutesRange = 1...10_080

    init(autoDisableMinutes: Int? = 30, minPowerPercent: Int = 10, disableOnLidOpen: Bool = true) {
        if let minutes = autoDisableMinutes, minutes > 0 {
            self.autoDisableMinutes = min(
                max(minutes, Self.customMinutesRange.lowerBound),
                Self.customMinutesRange.upperBound
            )
        } else {
            self.autoDisableMinutes = nil
        }
        self.minPowerPercent = min(
            max(minPowerPercent, Self.minPowerRange.lowerBound),
            Self.minPowerRange.upperBound
        )
        self.disableOnLidOpen = disableOnLidOpen
    }
}

extension AppSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case autoDisableMinutes
        case minPowerPercent
        case disableOnLidOpen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let minutes = try container.decodeIfPresent(Int.self, forKey: .autoDisableMinutes)
        let percent = try container.decodeIfPresent(Int.self, forKey: .minPowerPercent) ?? AppSettings.default.minPowerPercent
        let disableOnLidOpen = try container.decodeIfPresent(Bool.self, forKey: .disableOnLidOpen) ?? true
        // Missing key → default 30 minutes. Explicit 0 (or negative) → infinite.
        if container.contains(.autoDisableMinutes) {
            self.init(autoDisableMinutes: minutes, minPowerPercent: percent, disableOnLidOpen: disableOnLidOpen)
        } else {
            self.init(autoDisableMinutes: AppSettings.default.autoDisableMinutes, minPowerPercent: percent, disableOnLidOpen: disableOnLidOpen)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(autoDisableMinutes ?? 0, forKey: .autoDisableMinutes)
        try container.encode(minPowerPercent, forKey: .minPowerPercent)
        try container.encode(disableOnLidOpen, forKey: .disableOnLidOpen)
    }
}

enum WakeTimeoutChoice: Hashable {
    case minutes(Int)
    case custom
    case infinite

    static func from(storedMinutes: Int?) -> WakeTimeoutChoice {
        guard let storedMinutes else { return .infinite }
        if AppSettings.timeoutPresets.contains(storedMinutes) {
            return .minutes(storedMinutes)
        }
        return .custom
    }
}

struct WakeState: Codable {
    var enabledAt: Date?
}

@MainActor
final class AppSettingsStore: ObservableObject {
    static let directoryName = ".mac-power-switcher"

    @Published var settings: AppSettings

    let directoryURL: URL
    let settingsURL: URL
    let stateURL: URL

    init(fileManager: FileManager = .default) {
        let directory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(Self.directoryName, isDirectory: true)
        directoryURL = directory
        settingsURL = directory.appendingPathComponent("settings.json")
        stateURL = directory.appendingPathComponent("state.json")
        settings = Self.readSettings(from: settingsURL) ?? .default
    }

    var hasSettingsFile: Bool {
        FileManager.default.fileExists(atPath: settingsURL.path)
    }

    func save() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    func loadWakeState() -> WakeState {
        guard let data = try? Data(contentsOf: stateURL) else { return WakeState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WakeState.self, from: data)) ?? WakeState()
    }

    func saveWakeState(_ state: WakeState) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            // State is a convenience for timeout across relaunches; ignore disk errors.
        }
    }

    private static func readSettings(from url: URL) -> AppSettings? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
}
