import Foundation

struct ShortcutRule: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var key: KeyDescriptor
    var modifiers: ModifierSet
    var action: ShortcutAction
    var consumeOriginalEvent: Bool
    var isEnabled: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        key: KeyDescriptor,
        modifiers: ModifierSet,
        action: ShortcutAction,
        consumeOriginalEvent: Bool = true,
        isEnabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers.normalized
        self.action = action
        self.consumeOriginalEvent = consumeOriginalEvent
        self.isEnabled = isEnabled
        self.note = note
    }

    var displayShortcut: String { modifiers.displayString + key.displayName }
}
