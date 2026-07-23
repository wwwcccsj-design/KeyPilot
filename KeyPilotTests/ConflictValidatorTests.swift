import XCTest
@testable import KeyPilot

final class ConflictValidatorTests: XCTestCase {
    func testDisabledConflictsAreAllowed() throws {
        let rules = [
            RemapRule(source: TestFixtures.a, target: TestFixtures.b),
            RemapRule(source: TestFixtures.a, target: TestFixtures.c, isEnabled: false)
        ]
        XCTAssertNoThrow(try ConflictValidator.validateRemaps(rules))
    }

    func testShortcutRequiresModifier() {
        XCTAssertThrowsError(try ConflictValidator.validateShortcuts([TestFixtures.shortcut(modifiers: [])]))
    }

    func testDifferentModifiersCanShareMainKey() throws {
        let rules = [
            TestFixtures.shortcut(modifiers: [.command]),
            TestFixtures.shortcut(modifiers: [.option])
        ]
        XCTAssertNoThrow(try ConflictValidator.validateShortcuts(rules))
    }
}
