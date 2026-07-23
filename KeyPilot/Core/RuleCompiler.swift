import Foundation

struct RuleCompiler {
    func compile(_ configuration: AppConfiguration, version: UInt64) throws -> RuntimeRuleSnapshot {
        try ConflictValidator.validate(configuration)
        var remaps: [UInt16: UInt16] = [:]
        var hotkeys: [HotkeySignature: CompiledHotkeyAction] = [:]
        var multiPressActions: [UInt16: CompiledMultiPressAction] = [:]

        for rule in configuration.remapRules where rule.isEnabled {
            remaps[rule.source.keyCode] = rule.target.keyCode
            if rule.mode == .swap {
                remaps[rule.target.keyCode] = rule.source.keyCode
            }
        }

        for rule in configuration.shortcutRules where rule.isEnabled {
            let signature = HotkeySignature(keyCode: rule.key.keyCode, modifiers: rule.modifiers)
            hotkeys[signature] = CompiledHotkeyAction(
                ruleID: rule.id,
                action: rule.action,
                consumeOriginalEvent: rule.consumeOriginalEvent
            )
        }

        for rule in configuration.multiPressRules where rule.isEnabled {
            multiPressActions[rule.source.keyCode] = CompiledMultiPressAction(
                ruleID: rule.id,
                sourceKeyCode: rule.source.keyCode,
                pressCount: rule.pressCount,
                maxIntervalMilliseconds: rule.maxIntervalMilliseconds,
                action: rule.action
            )
        }

        return RuntimeRuleSnapshot(
            version: version,
            remapBySource: remaps,
            hotkeys: hotkeys,
            multiPressBySource: multiPressActions
        )
    }
}
