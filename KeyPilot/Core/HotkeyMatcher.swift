import CoreGraphics
import Foundation

final class HotkeyMatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var pressed: Set<HotkeySignature> = []

    func shouldTrigger(signature: HotkeySignature, eventType: CGEventType, isAutorepeat: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        switch eventType {
        case .keyDown:
            guard !isAutorepeat, !pressed.contains(signature) else { return false }
            pressed.insert(signature)
            return true
        case .keyUp:
            pressed.remove(signature)
            return false
        default:
            return false
        }
    }

    func release(keyCode: CGKeyCode) -> Set<HotkeySignature> {
        lock.lock()
        let released = Set(pressed.filter { $0.keyCode == keyCode })
        pressed.subtract(released)
        lock.unlock()
        return released
    }

    func reset() {
        lock.lock()
        pressed.removeAll()
        lock.unlock()
    }

    var pressedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pressed.count
    }
}
