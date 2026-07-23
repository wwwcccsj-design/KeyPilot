import Foundation

struct AppConfiguration: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var globalEnabled: Bool
    var launchAtLogin: Bool
    var showTriggerNotification: Bool
    var remapRules: [RemapRule]
    var shortcutRules: [ShortcutRule]
    var multiPressRules: [MultiPressRule]

    static var `default`: AppConfiguration {
        AppConfiguration(
            schemaVersion: currentSchemaVersion,
            globalEnabled: true,
            launchAtLogin: false,
            showTriggerNotification: false,
            remapRules: [],
            shortcutRules: [],
            multiPressRules: []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case globalEnabled
        case launchAtLogin
        case showTriggerNotification
        case remapRules
        case shortcutRules
        case multiPressRules
    }

    init(
        schemaVersion: Int,
        globalEnabled: Bool,
        launchAtLogin: Bool,
        showTriggerNotification: Bool,
        remapRules: [RemapRule],
        shortcutRules: [ShortcutRule],
        multiPressRules: [MultiPressRule]
    ) {
        self.schemaVersion = schemaVersion
        self.globalEnabled = globalEnabled
        self.launchAtLogin = launchAtLogin
        self.showTriggerNotification = showTriggerNotification
        self.remapRules = remapRules
        self.shortcutRules = shortcutRules
        self.multiPressRules = multiPressRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        globalEnabled = try container.decode(Bool.self, forKey: .globalEnabled)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        showTriggerNotification = try container.decode(Bool.self, forKey: .showTriggerNotification)
        remapRules = try container.decode([RemapRule].self, forKey: .remapRules)
        shortcutRules = try container.decode([ShortcutRule].self, forKey: .shortcutRules)
        multiPressRules = try container.decodeIfPresent([MultiPressRule].self, forKey: .multiPressRules) ?? []
    }
}
