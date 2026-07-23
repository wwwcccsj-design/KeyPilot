import CoreGraphics
import Foundation

struct KeyboardLayoutService {
    func descriptor(for keyCode: CGKeyCode) -> KeyDescriptor {
        KeyDescriptor(keyCode: keyCode, displayName: KeyCodeNames.name(for: keyCode), physicalLabel: nil)
    }
}
