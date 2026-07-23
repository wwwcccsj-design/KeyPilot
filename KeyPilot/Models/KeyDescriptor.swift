import CoreGraphics
import Foundation

struct KeyDescriptor: Codable, Hashable, Sendable {
    let keyCode: CGKeyCode
    let displayName: String
    let physicalLabel: String?

    init(keyCode: CGKeyCode, displayName: String? = nil, physicalLabel: String? = nil) {
        self.keyCode = keyCode
        self.displayName = displayName ?? KeyCodeNames.name(for: keyCode)
        self.physicalLabel = physicalLabel
    }
}
