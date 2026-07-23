import CoreGraphics
import Foundation

enum ConflictValidator {
    private struct Edge {
        let source: CGKeyCode
        let target: CGKeyCode
        let ruleID: UUID
    }

    static func validate(_ configuration: AppConfiguration) throws {
        guard configuration.schemaVersion == AppConfiguration.currentSchemaVersion else {
            throw KeyPilotError.unsupportedSchema(configuration.schemaVersion)
        }
        try validateRemaps(configuration.remapRules)
        try validateShortcuts(configuration.shortcutRules)
        try validateMultiPressRules(configuration.multiPressRules, remapRules: configuration.remapRules)
    }

    static func validateRemaps(_ rules: [RemapRule]) throws {
        let enabled = rules.filter(\.isEnabled)
        var sourceOwners: [CGKeyCode: UUID] = [:]
        var edges: [Edge] = []

        for rule in enabled {
            guard rule.source.keyCode != rule.target.keyCode else {
                throw KeyPilotError.invalidRule("“\(rule.source.displayName)” 不能映射到自身。")
            }

            let ruleEdges: [Edge]
            switch rule.mode {
            case .oneWay:
                ruleEdges = [Edge(source: rule.source.keyCode, target: rule.target.keyCode, ruleID: rule.id)]
            case .swap:
                ruleEdges = [
                    Edge(source: rule.source.keyCode, target: rule.target.keyCode, ruleID: rule.id),
                    Edge(source: rule.target.keyCode, target: rule.source.keyCode, ruleID: rule.id)
                ]
            }

            for edge in ruleEdges {
                if let owner = sourceOwners[edge.source], owner != rule.id {
                    throw KeyPilotError.conflictingRule("“\(KeyCodeNames.name(for: edge.source))” 已被另一条启用规则占用。")
                }
                sourceOwners[edge.source] = rule.id
                edges.append(edge)
            }
        }

        for edge in edges {
            if let targetOwner = sourceOwners[edge.target], targetOwner != edge.ruleID {
                throw KeyPilotError.conflictingRule(
                    "不支持链式映射：目标“\(KeyCodeNames.name(for: edge.target))”同时是另一条规则的源按键。"
                )
            }
        }
    }

    static func validateShortcuts(_ rules: [ShortcutRule]) throws {
        var signatures: Set<HotkeySignature> = []
        for rule in rules where rule.isEnabled {
            guard !rule.modifiers.normalized.isEmpty else {
                throw KeyPilotError.invalidRule("软件快捷键至少需要一个修饰键。")
            }
            let target = rule.action.applicationTarget
            guard target.applicationURL.isFileURL,
                  target.applicationURL.pathExtension.lowercased() == "app" else {
                throw KeyPilotError.invalidRule("软件目标必须是本地 .app 应用。")
            }
            let signature = HotkeySignature(keyCode: rule.key.keyCode, modifiers: rule.modifiers)
            guard signatures.insert(signature).inserted else {
                throw KeyPilotError.conflictingRule("快捷键 \(rule.displayShortcut) 已被使用。")
            }
        }
    }

    static func validateMultiPressRules(_ rules: [MultiPressRule], remapRules: [RemapRule] = []) throws {
        var sourceOwners: [CGKeyCode: UUID] = [:]
        let remappedSources = Set(remapRules.filter(\.isEnabled).flatMap { rule -> [CGKeyCode] in
            rule.mode == .swap
                ? [rule.source.keyCode, rule.target.keyCode]
                : [rule.source.keyCode]
        })

        for rule in rules where rule.isEnabled {
            guard MultiPressRule.allowedPressCounts.contains(rule.pressCount) else {
                throw KeyPilotError.invalidRule("连按次数必须在 2 到 4 次之间。")
            }
            guard MultiPressRule.allowedIntervalMilliseconds.contains(rule.maxIntervalMilliseconds) else {
                throw KeyPilotError.invalidRule("连按间隔必须在 150 到 1000 毫秒之间。")
            }
            guard sourceOwners[rule.source.keyCode] == nil else {
                throw KeyPilotError.conflictingRule("“\(rule.source.displayName)” 已被另一条连按规则占用。")
            }
            sourceOwners[rule.source.keyCode] = rule.id

            guard !remappedSources.contains(rule.source.keyCode) else {
                throw KeyPilotError.conflictingRule(
                    "“\(rule.source.displayName)” 已用作普通键位映射的源按键，不能同时作为连按触发键。"
                )
            }

            switch rule.action {
            case let .emitKey(target):
                guard target.keyCode != rule.source.keyCode else {
                    throw KeyPilotError.invalidRule("连按触发键不能输出自身。")
                }
            case let .launchApplication(target):
                guard target.applicationURL.isFileURL,
                      target.applicationURL.pathExtension.lowercased() == "app" else {
                    throw KeyPilotError.invalidRule("连按动作的软件目标必须是本地 .app 应用。")
                }
            }
        }
    }
}
