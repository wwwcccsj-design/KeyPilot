import Foundation
@testable import KeyPilot

enum TestFixtures {
    static let a = KeyDescriptor(keyCode: 0)
    static let b = KeyDescriptor(keyCode: 11)
    static let c = KeyDescriptor(keyCode: 8)
    static let comma = KeyDescriptor(keyCode: 43)
    static let n = KeyDescriptor(keyCode: 45)

    static func appTarget(url: URL = URL(fileURLWithPath: "/Applications/Test.app")) -> ApplicationTarget {
        ApplicationTarget(displayName: "Test", bundleIdentifier: "com.example.test", applicationURL: url)
    }

    static func shortcut(
        key: KeyDescriptor = c,
        modifiers: ModifierSet = [.command, .option],
        isEnabled: Bool = true,
        consume: Bool = true
    ) -> ShortcutRule {
        ShortcutRule(
            key: key,
            modifiers: modifiers,
            action: .launchApplication(appTarget()),
            consumeOriginalEvent: consume,
            isEnabled: isEnabled
        )
    }
}
