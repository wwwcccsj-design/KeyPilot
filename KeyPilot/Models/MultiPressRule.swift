import Foundation

enum MultiPressAction: Codable, Hashable, Sendable {
    case launchApplication(ApplicationTarget)
    case emitKey(KeyDescriptor)

    var displayName: String {
        switch self {
        case let .launchApplication(target):
            return "打开 \(target.displayName)"
        case let .emitKey(key):
            return "输出 \(key.displayName)"
        }
    }

    var applicationTarget: ApplicationTarget? {
        guard case let .launchApplication(target) = self else { return nil }
        return target
    }

    var outputKey: KeyDescriptor? {
        guard case let .emitKey(key) = self else { return nil }
        return key
    }
}

struct MultiPressRule: Identifiable, Codable, Hashable, Sendable {
    static let allowedPressCounts = 2...4
    static let allowedIntervalMilliseconds = 150...1_000

    let id: UUID
    var source: KeyDescriptor
    var pressCount: Int
    var maxIntervalMilliseconds: Int
    var action: MultiPressAction
    var isEnabled: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        source: KeyDescriptor,
        pressCount: Int = 2,
        maxIntervalMilliseconds: Int = 350,
        action: MultiPressAction,
        isEnabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.source = source
        self.pressCount = pressCount
        self.maxIntervalMilliseconds = maxIntervalMilliseconds
        self.action = action
        self.isEnabled = isEnabled
        self.note = note
    }

    var displayTrigger: String { "\(source.displayName) × \(pressCount)" }
}
