import CoreGraphics
import Foundation

struct HotkeySignature: Hashable, Sendable {
    let keyCode: CGKeyCode
    let modifiers: ModifierSet

    init(keyCode: CGKeyCode, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.modifiers = modifiers.normalized
    }
}

struct CompiledHotkeyAction: Hashable, Sendable {
    let ruleID: UUID
    let action: ShortcutAction
    let consumeOriginalEvent: Bool
}

struct CompiledMultiPressAction: Hashable, Sendable {
    let ruleID: UUID
    let sourceKeyCode: CGKeyCode
    let pressCount: Int
    let maxIntervalMilliseconds: Int
    let action: MultiPressAction
}

struct RuntimeRuleSnapshot: Sendable {
    let version: UInt64
    let remapBySource: [CGKeyCode: CGKeyCode]
    let hotkeys: [HotkeySignature: CompiledHotkeyAction]
    let multiPressBySource: [CGKeyCode: CompiledMultiPressAction]

    init(
        version: UInt64,
        remapBySource: [CGKeyCode: CGKeyCode],
        hotkeys: [HotkeySignature: CompiledHotkeyAction],
        multiPressBySource: [CGKeyCode: CompiledMultiPressAction] = [:]
    ) {
        self.version = version
        self.remapBySource = remapBySource
        self.hotkeys = hotkeys
        self.multiPressBySource = multiPressBySource
    }

    static let empty = RuntimeRuleSnapshot(
        version: 0,
        remapBySource: [:],
        hotkeys: [:],
        multiPressBySource: [:]
    )
}
