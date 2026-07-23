import CoreGraphics
import XCTest
@testable import KeyPilot

final class RemapMatcherTests: XCTestCase {
    func testKeyDownAndKeyUpAreBothRemapped() throws {
        let engine = KeyboardEventEngine(diagnostics: DiagnosticsService())
        let snapshot = RuntimeRuleSnapshot(
            version: 1,
            remapBySource: [TestFixtures.b.keyCode: TestFixtures.comma.keyCode],
            hotkeys: [:]
        )
        engine.update(snapshot: snapshot, globalEnabled: true)

        for type in [CGEventType.keyDown, .keyUp] {
            let event = try XCTUnwrap(CGEvent(
                keyboardEventSource: nil,
                virtualKey: TestFixtures.b.keyCode,
                keyDown: type == .keyDown
            ))
            let processed = try XCTUnwrap(engine.process(type: type, event: event))
            XCTAssertEqual(processed.getIntegerValueField(.keyboardEventKeycode), Int64(TestFixtures.comma.keyCode))
        }
    }

    func testGlobalPauseReturnsOriginalKey() throws {
        let engine = KeyboardEventEngine(diagnostics: DiagnosticsService())
        let snapshot = RuntimeRuleSnapshot(
            version: 1,
            remapBySource: [TestFixtures.b.keyCode: TestFixtures.comma.keyCode],
            hotkeys: [:]
        )
        engine.update(snapshot: snapshot, globalEnabled: false)
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.b.keyCode, keyDown: true))
        let processed = try XCTUnwrap(engine.process(type: .keyDown, event: event))
        XCTAssertEqual(processed.getIntegerValueField(.keyboardEventKeycode), Int64(TestFixtures.b.keyCode))
    }

    func testKeyUpUsesPressedMappingAfterRulesArePaused() throws {
        let engine = KeyboardEventEngine(diagnostics: DiagnosticsService())
        let snapshot = RuntimeRuleSnapshot(
            version: 1,
            remapBySource: [TestFixtures.b.keyCode: TestFixtures.comma.keyCode],
            hotkeys: [:]
        )
        engine.update(snapshot: snapshot, globalEnabled: true)
        let down = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.b.keyCode, keyDown: true))
        _ = engine.process(type: .keyDown, event: down)

        engine.update(snapshot: .empty, globalEnabled: false)
        let up = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: TestFixtures.b.keyCode, keyDown: false))
        let processed = try XCTUnwrap(engine.process(type: .keyUp, event: up))
        XCTAssertEqual(processed.getIntegerValueField(.keyboardEventKeycode), Int64(TestFixtures.comma.keyCode))
    }
}
