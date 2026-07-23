import CoreGraphics
import Foundation

final class KeyboardEventEngine: @unchecked Sendable {
    private struct BufferedPress {
        let flagsRawValue: UInt64
        var isReleased: Bool
    }

    private struct PendingMultiPressSequence {
        let rule: CompiledMultiPressAction
        var presses: [BufferedPress]
        var lastKeyDownTimestamp: CGEventTimestamp
        var generation: UInt64
    }

    private enum MultiPressEventResult {
        case unhandled
        case passThrough
        case consume
    }

    private static let syntheticEventMarker: Int64 = 0x4B_50_4C_54
    private let snapshot = AtomicBox(RuntimeRuleSnapshot.empty)
    private let globalEnabled = AtomicBox(true)
    private let eventTapManager: EventTapManager
    private let remapMatcher = RemapMatcher()
    private let hotkeyMatcher = HotkeyMatcher()
    private let actionQueue = DispatchQueue(label: "com.keypilot.actions", qos: .userInteractive)
    private let diagnostics: DiagnosticsService
    private let syntheticEventPoster: (CGEvent) -> Void
    private var pendingMultiPress: PendingMultiPressSequence?
    private var multiPressGeneration: UInt64 = 0
    private var suppressedKeyUps: Set<CGKeyCode> = []
    private var passThroughUntilKeyUp: Set<CGKeyCode> = []
    private var backgroundActivity: NSObjectProtocol?

    var onAction: ((UUID, ShortcutAction) -> Void)?
    var onStatusChange: ((EventTapStatus) -> Void)?

    init(
        eventTapManager: EventTapManager = EventTapManager(),
        diagnostics: DiagnosticsService,
        syntheticEventPoster: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }
    ) {
        self.eventTapManager = eventTapManager
        self.diagnostics = diagnostics
        self.syntheticEventPoster = syntheticEventPoster
        eventTapManager.onStatusChange = { [weak self] status in self?.handleStatus(status) }
        eventTapManager.onDisabled = { [weak diagnostics] type in
            let reason = type == .tapDisabledByTimeout ? "超时" : "用户输入"
            diagnostics?.record(.warning, module: "EventTap", message: "事件监听器因\(reason)被系统禁用，正在恢复。")
        }
    }

    func update(snapshot: RuntimeRuleSnapshot, globalEnabled: Bool) {
        flushPendingMultiPress()
        resetMultiPressState()
        self.snapshot.value = snapshot
        self.globalEnabled.value = globalEnabled
        if !globalEnabled { hotkeyMatcher.reset() }
        diagnostics.record(.info, module: "Rules", message: "规则快照已更新，版本 \(snapshot.version)。")
    }

    func start() throws {
        try eventTapManager.start { [weak self] type, event in
            self?.process(type: type, event: event) ?? event
        }
        if backgroundActivity == nil {
            backgroundActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
                reason: "KeyPilot 全局键盘规则需要在后台保持响应"
            )
            diagnostics.record(.info, module: "EventTap", message: "后台低延迟活动已启用。")
        }
    }

    func stop() {
        flushPendingMultiPress()
        resetMultiPressState()
        for target in remapMatcher.drainPressedTargets() {
            CGEvent(keyboardEventSource: nil, virtualKey: target, keyDown: false)?.post(tap: .cghidEventTap)
        }
        eventTapManager.stop()
        hotkeyMatcher.reset()
        if let backgroundActivity {
            ProcessInfo.processInfo.endActivity(backgroundActivity)
            self.backgroundActivity = nil
        }
    }

    func restart() throws {
        stop()
        try start()
    }

    func process(type: CGEventType, event: CGEvent) -> CGEvent? {
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else { return event }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return event
        }
        let descriptor = KeyEventDescriptor(eventType: type, event: event)
        let currentSnapshot = snapshot.value

        if !globalEnabled.value {
            if type == .keyUp, let target = remapMatcher.releaseTarget(for: descriptor.keyCode) {
                event.setIntegerValueField(.keyboardEventKeycode, value: Int64(target))
            }
            return event
        }

        switch processMultiPress(
            descriptor: descriptor,
            event: event,
            snapshot: currentSnapshot
        ) {
        case .consume:
            return nil
        case .passThrough:
            return event
        case .unhandled:
            break
        }

        if type == .keyUp {
            let released = hotkeyMatcher.release(keyCode: descriptor.keyCode)
            if let hotkey = released.compactMap({ currentSnapshot.hotkeys[$0] }).first {
                return hotkey.consumeOriginalEvent ? nil : event
            }
        }

        if type == .keyDown || type == .keyUp {
            let signature = HotkeySignature(keyCode: descriptor.keyCode, modifiers: descriptor.modifiers)
            if let hotkey = currentSnapshot.hotkeys[signature] {
                if type == .keyDown,
                   hotkeyMatcher.shouldTrigger(
                       signature: signature,
                       eventType: type,
                       isAutorepeat: descriptor.isAutorepeat
                   ) {
                    actionQueue.async { [weak self] in
                        self?.onAction?(hotkey.ruleID, hotkey.action)
                    }
                }
                return hotkey.consumeOriginalEvent ? nil : event
            }
        }

        if type == .keyDown || type == .keyUp,
           let target = remapMatcher.target(
               for: descriptor.keyCode,
               eventType: type,
               in: currentSnapshot
           ) {
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(target))
        }
        return event
    }

    private func processMultiPress(
        descriptor: KeyEventDescriptor,
        event: CGEvent,
        snapshot: RuntimeRuleSnapshot
    ) -> MultiPressEventResult {
        let keyCode = descriptor.keyCode

        if descriptor.eventType == .flagsChanged {
            flushPendingMultiPress()
            return .passThrough
        }

        if passThroughUntilKeyUp.contains(keyCode) {
            if descriptor.eventType == .keyUp {
                passThroughUntilKeyUp.remove(keyCode)
            }
            return .passThrough
        }

        if descriptor.eventType == .keyUp, suppressedKeyUps.remove(keyCode) != nil {
            return .consume
        }

        if descriptor.eventType == .keyDown,
           let pending = pendingMultiPress,
           pending.rule.sourceKeyCode != keyCode {
            flushPendingMultiPress()
        }

        guard let rule = snapshot.multiPressBySource[keyCode] else {
            return .unhandled
        }

        guard descriptor.modifiers.isEmpty else {
            if pendingMultiPress?.rule.sourceKeyCode == keyCode {
                flushPendingMultiPress()
            }
            return .unhandled
        }

        switch descriptor.eventType {
        case .keyDown:
            if descriptor.isAutorepeat {
                if pendingMultiPress?.rule.sourceKeyCode == keyCode {
                    flushPendingMultiPress()
                }
                return .passThrough
            }

            if let pending = pendingMultiPress,
               pending.rule.sourceKeyCode == keyCode,
               event.timestamp > pending.lastKeyDownTimestamp,
               event.timestamp - pending.lastKeyDownTimestamp > intervalNanoseconds(for: pending.rule) {
                flushPendingMultiPress()
            }

            if pendingMultiPress?.rule.sourceKeyCode == keyCode {
                multiPressGeneration &+= 1
                pendingMultiPress?.presses.append(BufferedPress(
                    flagsRawValue: event.flags.rawValue,
                    isReleased: false
                ))
                pendingMultiPress?.lastKeyDownTimestamp = event.timestamp
                pendingMultiPress?.generation = multiPressGeneration
            } else {
                multiPressGeneration &+= 1
                pendingMultiPress = PendingMultiPressSequence(
                    rule: rule,
                    presses: [BufferedPress(flagsRawValue: event.flags.rawValue, isReleased: false)],
                    lastKeyDownTimestamp: event.timestamp,
                    generation: multiPressGeneration
                )
            }

            guard let pending = pendingMultiPress else { return .passThrough }
            if pending.presses.count >= pending.rule.pressCount {
                pendingMultiPress = nil
                multiPressGeneration &+= 1
                suppressedKeyUps.insert(keyCode)
                triggerMultiPress(pending.rule, flagsRawValue: event.flags.rawValue)
            } else {
                scheduleMultiPressExpiration(for: pending)
            }
            return .consume

        case .keyUp:
            guard pendingMultiPress?.rule.sourceKeyCode == keyCode,
                  let lastIndex = pendingMultiPress?.presses.indices.last,
                  pendingMultiPress?.presses[lastIndex].isReleased == false else {
                return .passThrough
            }
            pendingMultiPress?.presses[lastIndex].isReleased = true
            return .consume

        default:
            return .unhandled
        }
    }

    private func scheduleMultiPressExpiration(for pending: PendingMultiPressSequence) {
        let generation = pending.generation
        let ruleID = pending.rule.ruleID
        let delay = Double(pending.rule.maxIntervalMilliseconds) / 1_000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  let current = self.pendingMultiPress,
                  current.generation == generation,
                  current.rule.ruleID == ruleID else { return }
            self.flushPendingMultiPress()
        }
    }

    private func flushPendingMultiPress() {
        guard let pending = pendingMultiPress else { return }
        pendingMultiPress = nil
        multiPressGeneration &+= 1

        for press in pending.presses {
            postSyntheticKey(
                pending.rule.sourceKeyCode,
                isDown: true,
                flagsRawValue: press.flagsRawValue
            )
            if press.isReleased {
                postSyntheticKey(
                    pending.rule.sourceKeyCode,
                    isDown: false,
                    flagsRawValue: press.flagsRawValue
                )
            } else {
                passThroughUntilKeyUp.insert(pending.rule.sourceKeyCode)
            }
        }
    }

    private func resetMultiPressState() {
        pendingMultiPress = nil
        multiPressGeneration &+= 1
        suppressedKeyUps.removeAll()
        passThroughUntilKeyUp.removeAll()
    }

    private func triggerMultiPress(_ rule: CompiledMultiPressAction, flagsRawValue: UInt64) {
        switch rule.action {
        case let .launchApplication(target):
            actionQueue.async { [weak self] in
                self?.onAction?(rule.ruleID, .launchApplication(target))
            }
        case let .emitKey(target):
            actionQueue.async { [weak self] in
                self?.postSyntheticKey(target.keyCode, isDown: true, flagsRawValue: flagsRawValue)
                self?.postSyntheticKey(target.keyCode, isDown: false, flagsRawValue: flagsRawValue)
                self?.diagnostics.record(
                    .info,
                    module: "MultiPress",
                    message: "连按规则 \(rule.ruleID.uuidString) 已输出 \(target.displayName)。"
                )
            }
        }
    }

    private func postSyntheticKey(_ keyCode: CGKeyCode, isDown: Bool, flagsRawValue: UInt64) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else { return }
        event.flags = CGEventFlags(rawValue: flagsRawValue)
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        syntheticEventPoster(event)
    }

    private func intervalNanoseconds(for rule: CompiledMultiPressAction) -> UInt64 {
        UInt64(rule.maxIntervalMilliseconds) * 1_000_000
    }

    private func handleStatus(_ status: EventTapStatus) {
        onStatusChange?(status)
        switch status {
        case .running:
            diagnostics.record(.info, module: "EventTap", message: "键盘事件引擎运行中。")
        case let .failed(message):
            diagnostics.record(.error, module: "EventTap", message: message)
        default:
            break
        }
    }
}
