import Foundation
import XCTest
@testable import KeyPilot

final class ConfigurationStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var store: ConfigurationStore!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPilotTests-\(UUID().uuidString)", isDirectory: true)
        store = ConfigurationStore(directoryURL: directoryURL)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
        store = nil
        directoryURL = nil
    }

    func testDefaultConfigurationIsCreated() throws {
        let configuration = try store.load()
        XCTAssertEqual(configuration, .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configurationURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    func testSaveThenLoadRoundTrips() throws {
        var expected = AppConfiguration.default
        expected.remapRules = [RemapRule(source: TestFixtures.b, target: TestFixtures.comma, mode: .swap)]
        try store.save(expected)
        XCTAssertEqual(try store.load(), expected)
    }

    func testAtomicSaveLeavesOnlyConfigurationAndBackup() throws {
        try store.save(.default)
        let names = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path).sorted()
        XCTAssertEqual(names, ["config.backup.json", "config.json"])
    }

    func testCorruptPrimaryRecoversBackup() throws {
        var expected = AppConfiguration.default
        expected.remapRules = [RemapRule(source: TestFixtures.a, target: TestFixtures.b)]
        try store.save(expected)
        try Data("not json".utf8).write(to: store.configurationURL, options: .atomic)
        XCTAssertEqual(try store.load(), expected)
    }

    func testCorruptImportDoesNotOverwriteCurrentConfiguration() throws {
        var expected = AppConfiguration.default
        expected.remapRules = [RemapRule(source: TestFixtures.a, target: TestFixtures.b)]
        try store.save(expected)
        let importURL = directoryURL.appendingPathComponent("broken.json")
        try Data("{".utf8).write(to: importURL)
        XCTAssertThrowsError(try store.validateImport(from: importURL))
        XCTAssertEqual(try store.load(), expected)
    }

    func testLegacyConfigurationWithoutMultiPressRulesStillLoads() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "globalEnabled": true,
          "launchAtLogin": false,
          "showTriggerNotification": false,
          "remapRules": [],
          "shortcutRules": []
        }
        """
        try Data(legacyJSON.utf8).write(to: store.configurationURL, options: .atomic)

        let configuration = try store.load()

        XCTAssertEqual(configuration.multiPressRules, [])
    }

    func testUnsupportedSchemaIsRejected() throws {
        var candidate = AppConfiguration.default
        candidate.schemaVersion = 99
        let url = directoryURL.appendingPathComponent("future.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(candidate).write(to: url)
        XCTAssertThrowsError(try store.validateImport(from: url)) { error in
            guard case KeyPilotError.unsupportedSchema(99) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testConflictingImportedRulesAreRejected() throws {
        var candidate = AppConfiguration.default
        candidate.remapRules = [
            RemapRule(source: TestFixtures.a, target: TestFixtures.b),
            RemapRule(source: TestFixtures.a, target: TestFixtures.c)
        ]
        let url = directoryURL.appendingPathComponent("conflict.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(candidate).write(to: url)
        XCTAssertThrowsError(try store.validateImport(from: url))
    }
}
