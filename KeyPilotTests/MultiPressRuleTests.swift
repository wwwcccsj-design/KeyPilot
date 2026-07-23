import CoreGraphics
import XCTest
@testable import KeyPilot

final class MultiPressRuleTests: XCTestCase {
    func testCompilerIncludesEnabledMultiPressRule() throws {
        var configuration = AppConfiguration.default
        let rule = MultiPressRule(
            source: TestFixtures.a,
            pressCount: 2,
            maxIntervalMilliseconds: 300,
            action: .emitKey(TestFixtures.b)
        )
        configuration.multiPressRules = [rule]

        let snapshot = try RuleCompiler().compile(configuration, version: 7)

        XCTAssertEqual(snapshot.multiPressBySource[TestFixtures.a.keyCode]?.ruleID, rule.id)
        XCTAssertEqual(snapshot.multiPressBySource[TestFixtures.a.keyCode]?.pressCount, 2)
    }

    func testDuplicateSourceAndRemapConflictAreRejected() {
        let first = MultiPressRule(source: TestFixtures.a, action: .emitKey(TestFixtures.b))
        let second = MultiPressRule(source: TestFixtures.a, action: .emitKey(TestFixtures.c))

        XCTAssertThrowsError(try ConflictValidator.validateMultiPressRules([first, second]))
        XCTAssertThrowsError(try ConflictValidator.validateMultiPressRules(
            [first],
            remapRules: [RemapRule(source: TestFixtures.a, target: TestFixtures.b)]
        ))
    }

    func testCompletedDoublePressEmitsOnlyTargetKey() throws {
        let outputExpectation = expectation(description: "target key emitted")
        let lock = NSLock()
        var posted: [(CGKeyCode, Bool)] = []
        let engine = KeyboardEventEngine(
            diagnostics: DiagnosticsService(),
            syntheticEventPoster: { event in
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let isDown = event.type == .keyDown
                lock.lock()
                posted.append((keyCode, isDown))
                let isComplete = posted.count == 2
                lock.unlock()
                if isComplete { outputExpectation.fulfill() }
            }
        )
        var configuration = AppConfiguration.default
        configuration.multiPressRules = [MultiPressRule(
            source: TestFixtures.a,
            pressCount: 2,
            maxIntervalMilliseconds: 300,
            action: .emitKey(TestFixtures.b)
        )]
        engine.update(snapshot: try RuleCompiler().compile(configuration, version: 1), globalEnabled: true)

        XCTAssertNil(engine.process(type: .keyDown, event: try keyEvent(TestFixtures.a.keyCode, isDown: true)))
        XCTAssertNil(engine.process(type: .keyUp, event: try keyEvent(TestFixtures.a.keyCode, isDown: false)))
        XCTAssertNil(engine.process(type: .keyDown, event: try keyEvent(TestFixtures.a.keyCode, isDown: true)))
        XCTAssertNil(engine.process(type: .keyUp, event: try keyEvent(TestFixtures.a.keyCode, isDown: false)))

        wait(for: [outputExpectation], timeout: 1.0)
        lock.lock()
        let result = posted
        lock.unlock()
        XCTAssertEqual(result.map(\.0), [TestFixtures.b.keyCode, TestFixtures.b.keyCode])
        XCTAssertEqual(result.map(\.1), [true, false])
    }

    func testIncompletePressIsReplayedAfterTimeout() throws {
        let replayExpectation = expectation(description: "source key replayed")
        let lock = NSLock()
        var posted: [(CGKeyCode, Bool)] = []
        let engine = KeyboardEventEngine(
            diagnostics: DiagnosticsService(),
            syntheticEventPoster: { event in
                let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let isDown = event.type == .keyDown
                lock.lock()
                posted.append((keyCode, isDown))
                let isComplete = posted.count == 2
                lock.unlock()
                if isComplete { replayExpectation.fulfill() }
            }
        )
        var configuration = AppConfiguration.default
        configuration.multiPressRules = [MultiPressRule(
            source: TestFixtures.a,
            pressCount: 2,
            maxIntervalMilliseconds: 150,
            action: .emitKey(TestFixtures.b)
        )]
        engine.update(snapshot: try RuleCompiler().compile(configuration, version: 1), globalEnabled: true)

        XCTAssertNil(engine.process(type: .keyDown, event: try keyEvent(TestFixtures.a.keyCode, isDown: true)))
        XCTAssertNil(engine.process(type: .keyUp, event: try keyEvent(TestFixtures.a.keyCode, isDown: false)))

        wait(for: [replayExpectation], timeout: 1.0)
        lock.lock()
        let result = posted
        lock.unlock()
        XCTAssertEqual(result.map(\.0), [TestFixtures.a.keyCode, TestFixtures.a.keyCode])
        XCTAssertEqual(result.map(\.1), [true, false])
    }

    func testModifiedKeyDoesNotStartMultiPressSequence() throws {
        let engine = KeyboardEventEngine(
            diagnostics: DiagnosticsService(),
            syntheticEventPoster: { _ in XCTFail("modified input must not be buffered") }
        )
        var configuration = AppConfiguration.default
        configuration.multiPressRules = [MultiPressRule(
            source: TestFixtures.a,
            action: .emitKey(TestFixtures.b)
        )]
        engine.update(snapshot: try RuleCompiler().compile(configuration, version: 1), globalEnabled: true)
        let event = try keyEvent(TestFixtures.a.keyCode, isDown: true)
        event.flags = .maskCommand

        XCTAssertNotNil(engine.process(type: .keyDown, event: event))
    }

    private func keyEvent(_ keyCode: CGKeyCode, isDown: Bool) throws -> CGEvent {
        try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown))
    }
}
