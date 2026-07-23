import AppKit
import Foundation
import XCTest
@testable import KeyPilot

@MainActor
final class ApplicationLauncherTests: XCTestCase {
    func testRunningBackgroundApplicationIsAlsoReopened() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPilotLauncherTests-\(UUID().uuidString)", isDirectory: true)
        let applicationURL = directory.appendingPathComponent("Target.app", isDirectory: true)
        try FileManager.default.createDirectory(at: applicationURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let running = LauncherRunningApplication(bundleIdentifier: "com.example.target")
        let workspace = LauncherWorkspace(runningApplication: running)
        let launcher = ApplicationLauncher(
            resolver: ApplicationResolver(workspace: workspace),
            diagnostics: DiagnosticsService()
        )
        let target = ApplicationTarget(
            displayName: "Target",
            bundleIdentifier: "com.example.target",
            applicationURL: applicationURL
        )

        launcher.perform(ruleID: UUID(), action: .launchApplication(target))

        XCTAssertTrue(running.didUnhide)
        XCTAssertTrue(running.didActivate)
        XCTAssertEqual(workspace.openedURLs, [applicationURL])
        XCTAssertTrue(workspace.lastConfiguration?.activates == true)
        XCTAssertTrue(workspace.lastConfiguration?.createsNewApplicationInstance == false)
    }
}

private final class LauncherRunningApplication: RunningApplicationProviding {
    let bundleIdentifier: String?
    private(set) var didUnhide = false
    private(set) var didActivate = false

    init(bundleIdentifier: String?) {
        self.bundleIdentifier = bundleIdentifier
    }

    func unhide() -> Bool {
        didUnhide = true
        return true
    }

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        didActivate = true
        return true
    }
}

private final class LauncherWorkspace: WorkspaceProviding {
    let runningApplicationValue: RunningApplicationProviding?
    private(set) var openedURLs: [URL] = []
    private(set) var lastConfiguration: NSWorkspace.OpenConfiguration?

    init(runningApplication: RunningApplicationProviding?) {
        runningApplicationValue = runningApplication
    }

    func runningApplication(bundleIdentifier: String) -> RunningApplicationProviding? {
        runningApplicationValue?.bundleIdentifier == bundleIdentifier ? runningApplicationValue : nil
    }

    func applicationURL(bundleIdentifier: String) -> URL? { nil }

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: @escaping (NSRunningApplication?, Error?) -> Void
    ) {
        openedURLs.append(url)
        lastConfiguration = configuration
        completionHandler(nil, nil)
    }
}
