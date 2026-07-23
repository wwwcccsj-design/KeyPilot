import AppKit
import Foundation
import XCTest
@testable import KeyPilot

final class ApplicationResolverTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPilotResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
    }

    func testRunningApplicationIsFoundByBundleIdentifier() throws {
        let running = MockRunningApplication(bundleIdentifier: "com.example.test")
        let workspace = MockWorkspace(runningApplication: running)
        let resolver = ApplicationResolver(workspace: workspace)
        let resolution = try resolver.resolve(TestFixtures.appTarget())
        guard case let .activate(application) = resolution else {
            return XCTFail("Expected an activation request")
        }
        XCTAssertEqual(application.bundleIdentifier, "com.example.test")
        XCTAssertTrue(application.activate(options: [.activateAllWindows]))
        XCTAssertTrue(running.didActivate)
    }

    func testInvalidURLReturnsNotFound() {
        let resolver = ApplicationResolver(workspace: MockWorkspace())
        XCTAssertThrowsError(try resolver.resolve(TestFixtures.appTarget())) { error in
            guard case KeyPilotError.applicationNotFound = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidTargetFormsOpenRequest() throws {
        let appURL = directoryURL.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        let resolver = ApplicationResolver(workspace: MockWorkspace())
        let resolution = try resolver.resolve(TestFixtures.appTarget(url: appURL))
        guard case let .open(url) = resolution else {
            return XCTFail("Expected an open request")
        }
        XCTAssertEqual(url, appURL)
    }

    func testBundleIdentifierRelocatesMissingSavedPath() throws {
        let relocatedURL = directoryURL.appendingPathComponent("Relocated.app", isDirectory: true)
        try FileManager.default.createDirectory(at: relocatedURL, withIntermediateDirectories: true)
        let workspace = MockWorkspace(resolvedURL: relocatedURL)
        let resolver = ApplicationResolver(workspace: workspace)
        let resolution = try resolver.resolve(TestFixtures.appTarget())
        guard case let .open(url) = resolution else {
            return XCTFail("Expected relocated open request")
        }
        XCTAssertEqual(url, relocatedURL)
    }
}

private final class MockRunningApplication: RunningApplicationProviding {
    let bundleIdentifier: String?
    private(set) var didActivate = false

    init(bundleIdentifier: String?) {
        self.bundleIdentifier = bundleIdentifier
    }

    func unhide() -> Bool { true }

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        didActivate = true
        return true
    }
}

private final class MockWorkspace: WorkspaceProviding {
    let runningApplicationValue: RunningApplicationProviding?
    let resolvedURL: URL?

    init(runningApplication: RunningApplicationProviding? = nil, resolvedURL: URL? = nil) {
        runningApplicationValue = runningApplication
        self.resolvedURL = resolvedURL
    }

    func runningApplication(bundleIdentifier: String) -> RunningApplicationProviding? {
        runningApplicationValue?.bundleIdentifier == bundleIdentifier ? runningApplicationValue : nil
    }

    func applicationURL(bundleIdentifier: String) -> URL? { resolvedURL }

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: @escaping (NSRunningApplication?, Error?) -> Void
    ) {
        completionHandler(nil, nil)
    }
}
