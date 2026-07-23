import CoreGraphics
import Foundation

final class RemapMatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var pressedMappings: [CGKeyCode: CGKeyCode] = [:]

    func target(
        for source: CGKeyCode,
        eventType: CGEventType,
        in snapshot: RuntimeRuleSnapshot
    ) -> CGKeyCode? {
        lock.lock()
        defer { lock.unlock() }
        switch eventType {
        case .keyDown:
            guard let target = snapshot.remapBySource[source] else { return nil }
            pressedMappings[source] = target
            return target
        case .keyUp:
            if let target = pressedMappings.removeValue(forKey: source) { return target }
            return snapshot.remapBySource[source]
        default:
            return nil
        }
    }

    func releaseTarget(for source: CGKeyCode) -> CGKeyCode? {
        lock.lock()
        defer { lock.unlock() }
        return pressedMappings.removeValue(forKey: source)
    }

    func drainPressedTargets() -> [CGKeyCode] {
        lock.lock()
        defer { lock.unlock() }
        let targets = Array(pressedMappings.values)
        pressedMappings.removeAll()
        return targets
    }
}
