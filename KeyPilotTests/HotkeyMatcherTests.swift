import CoreGraphics
import XCTest
@testable import KeyPilot

final class HotkeyMatcherTests: XCTestCase {
    func testAllSupportedModifiersNormalizeAndMatch() throws {
        let modifiers: ModifierSet = [.command, .option, .control, .shift]
        let signature = HotkeySignature(keyCode: TestFixtures.c.keyCode, modifiers: modifiers)
        XCTAssertEqual(signature.modifiers, modifiers)
        XCTAssertEqual(signature.modifiers.displayString, "⌃⌥⇧⌘")
    }

    func testUnrelatedCGFlagsAreIgnored() {
        let flags: CGEventFlags = [.maskCommand, .maskAlternate, .maskAlphaShift, .maskNumericPad]
        XCTAssertEqual(ModifierSet(cgFlags: flags), [.command, .option])
    }

    func testDuplicateHotkeyThrows() {
        var configuration = AppConfiguration.default
        configuration.shortcutRules = [TestFixtures.shortcut(), TestFixtures.shortcut()]
        XCTAssertThrowsError(try RuleCompiler().compile(configuration, version: 1))
    }

    func testFirstKeyDownTriggersOnlyOnce() {
        let matcher = HotkeyMatcher()
        let signature = HotkeySignature(keyCode: TestFixtures.c.keyCode, modifiers: [.command])
        XCTAssertTrue(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false))
        XCTAssertFalse(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false))
    }

    func testAutorepeatDoesNotTrigger() {
        let matcher = HotkeyMatcher()
        let signature = HotkeySignature(keyCode: TestFixtures.c.keyCode, modifiers: [.command])
        XCTAssertFalse(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: true))
    }

    func testKeyUpReleaseAllowsNextTrigger() {
        let matcher = HotkeyMatcher()
        let signature = HotkeySignature(keyCode: TestFixtures.c.keyCode, modifiers: [.command])
        XCTAssertTrue(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false))
        _ = matcher.release(keyCode: signature.keyCode)
        XCTAssertTrue(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false))
    }

    func testKeyUpStillReleasesAfterModifierWasReleasedFirst() throws {
        let engine = KeyboardEventEngine(diagnostics: DiagnosticsService())
        var configuration = AppConfiguration.default
        configuration.shortcutRules = [TestFixtures.shortcut(modifiers: [.command], consume: true)]
        engine.update(snapshot: try RuleCompiler().compile(configuration, version: 1), globalEnabled: true)

        let down = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.c.keyCode, keyDown: true))
        down.flags = [.maskCommand]
        XCTAssertNil(engine.process(type: .keyDown, event: down))

        let up = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.c.keyCode, keyDown: false))
        up.flags = []
        XCTAssertNil(engine.process(type: .keyUp, event: up))
    }

    func testHotkeyHasPriorityOverRemap() throws {
        let diagnostics = DiagnosticsService()
        let engine = KeyboardEventEngine(diagnostics: diagnostics)
        var configuration = AppConfiguration.default
        configuration.remapRules = [RemapRule(source: TestFixtures.c, target: TestFixtures.b)]
        configuration.shortcutRules = [TestFixtures.shortcut(modifiers: [.command], consume: false)]
        engine.update(snapshot: try RuleCompiler().compile(configuration, version: 1), globalEnabled: true)

        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.c.keyCode, keyDown: true))
        event.flags = [.maskCommand]
        let processed = try XCTUnwrap(engine.process(type: .keyDown, event: event))
        XCTAssertEqual(processed.getIntegerValueField(.keyboardEventKeycode), Int64(TestFixtures.c.keyCode))
    }
}
