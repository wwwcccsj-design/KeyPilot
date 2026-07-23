import CoreGraphics
import Foundation

struct KeyEventDescriptor: Sendable {
    let keyCode: CGKeyCode
    let eventType: CGEventType
    let modifiers: ModifierSet
    let isAutorepeat: Bool

    init(eventType: CGEventType, event: CGEvent) {
        keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        self.eventType = eventType
        modifiers = ModifierSet(cgFlags: event.flags)
        isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}
