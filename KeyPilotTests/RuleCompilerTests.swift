import XCTest
@testable import KeyPilot

final class RuleCompilerTests: XCTestCase {
    private let compiler = RuleCompiler()

    func testOneWayMappingCompiles() throws {
        var configuration = AppConfiguration.default
        configuration.remapRules = [RemapRule(source: TestFixtures.a, target: TestFixtures.b)]
        let snapshot = try compiler.compile(configuration, version: 1)
        XCTAssertEqual(snapshot.remapBySource[TestFixtures.a.keyCode], TestFixtures.b.keyCode)
        XCTAssertNil(snapshot.remapBySource[TestFixtures.b.keyCode])
    }

    func testSwapCompilesToTwoMappings() throws {
        var configuration = AppConfiguration.default
        configuration.remapRules = [RemapRule(source: TestFixtures.b, target: TestFixtures.comma, mode: .swap)]
        let snapshot = try compiler.compile(configuration, version: 2)
        XCTAssertEqual(snapshot.remapBySource[TestFixtures.b.keyCode], TestFixtures.comma.keyCode)
        XCTAssertEqual(snapshot.remapBySource[TestFixtures.comma.keyCode], TestFixtures.b.keyCode)
    }

    func testDisabledRuleIsIgnored() throws {
        var configuration = AppConfiguration.default
        configuration.remapRules = [RemapRule(source: TestFixtures.a, target: TestFixtures.b, isEnabled: false)]
        XCTAssertTrue(try compiler.compile(configuration, version: 1).remapBySource.isEmpty)
    }

    func testDuplicateSourceThrows() {
        var configuration = AppConfiguration.default
        configuration.remapRules = [
            RemapRule(source: TestFixtures.b, target: TestFixtures.comma),
            RemapRule(source: TestFixtures.b, target: TestFixtures.n)
        ]
        XCTAssertThrowsError(try compiler.compile(configuration, version: 1))
    }

    func testSelfMappingThrows() {
        var configuration = AppConfiguration.default
        configuration.remapRules = [RemapRule(source: TestFixtures.b, target: TestFixtures.b)]
        XCTAssertThrowsError(try compiler.compile(configuration, version: 1))
    }

    func testComplexChainThrows() {
        var configuration = AppConfiguration.default
        configuration.remapRules = [
            RemapRule(source: TestFixtures.a, target: TestFixtures.b),
            RemapRule(source: TestFixtures.b, target: TestFixtures.c)
        ]
        XCTAssertThrowsError(try compiler.compile(configuration, version: 1))
    }

    func testSwapOccupancyConflictThrows() {
        var configuration = AppConfiguration.default
        configuration.remapRules = [
            RemapRule(source: TestFixtures.b, target: TestFixtures.comma, mode: .swap),
            RemapRule(source: TestFixtures.comma, target: TestFixtures.n)
        ]
        XCTAssertThrowsError(try compiler.compile(configuration, version: 1))
    }
}
