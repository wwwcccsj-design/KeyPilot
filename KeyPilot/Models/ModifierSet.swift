import AppKit
import CoreGraphics
import Foundation

struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let command = ModifierSet(rawValue: 1 << 0)
    static let option = ModifierSet(rawValue: 1 << 1)
    static let control = ModifierSet(rawValue: 1 << 2)
    static let shift = ModifierSet(rawValue: 1 << 3)
    static let supported: ModifierSet = [.command, .option, .control, .shift]

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(cgFlags: CGEventFlags) {
        var value: ModifierSet = []
        if cgFlags.contains(.maskCommand) { value.insert(.command) }
        if cgFlags.contains(.maskAlternate) { value.insert(.option) }
        if cgFlags.contains(.maskControl) { value.insert(.control) }
        if cgFlags.contains(.maskShift) { value.insert(.shift) }
        self = value
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var value: ModifierSet = []
        if eventFlags.contains(.command) { value.insert(.command) }
        if eventFlags.contains(.option) { value.insert(.option) }
        if eventFlags.contains(.control) { value.insert(.control) }
        if eventFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }

    var normalized: ModifierSet { intersection(.supported) }

    var displayString: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}
