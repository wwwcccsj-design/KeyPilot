import AppKit
import Foundation
import UniformTypeIdentifiers

protocol RunningApplicationProviding: AnyObject {
    var bundleIdentifier: String? { get }
    @discardableResult func unhide() -> Bool
    @discardableResult func activate(options: NSApplication.ActivationOptions) -> Bool
}

extension NSRunningApplication: RunningApplicationProviding {}

protocol WorkspaceProviding {
    func runningApplication(bundleIdentifier: String) -> RunningApplicationProviding?
    func applicationURL(bundleIdentifier: String) -> URL?
    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: @escaping (NSRunningApplication?, Error?) -> Void
    )
}

struct SystemWorkspace: WorkspaceProviding {
    func runningApplication(bundleIdentifier: String) -> RunningApplicationProviding? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    func applicationURL(bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: @escaping (NSRunningApplication?, Error?) -> Void
    ) {
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: completionHandler)
    }
}

enum ApplicationResolution {
    case activate(RunningApplicationProviding)
    case open(URL)
}

struct ApplicationResolver {
    let workspace: WorkspaceProviding
    let fileManager: FileManager

    init(workspace: WorkspaceProviding = SystemWorkspace(), fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    func resolve(_ target: ApplicationTarget) throws -> ApplicationResolution {
        if let bundleIdentifier = target.bundleIdentifier,
           let running = workspace.runningApplication(bundleIdentifier: bundleIdentifier) {
            return .activate(running)
        }

        if fileManager.fileExists(atPath: target.applicationURL.path) {
            return .open(target.applicationURL)
        }

        if let bundleIdentifier = target.bundleIdentifier,
           let resolvedURL = workspace.applicationURL(bundleIdentifier: bundleIdentifier),
           fileManager.fileExists(atPath: resolvedURL.path) {
            return .open(resolvedURL)
        }
        throw KeyPilotError.applicationNotFound
    }

    @MainActor
    static func chooseApplication() -> ApplicationTarget? {
        let panel = NSOpenPanel()
        panel.title = "选择要打开或激活的应用"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let bundle = Bundle(url: url)
        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return ApplicationTarget(
            displayName: displayName,
            bundleIdentifier: bundle?.bundleIdentifier,
            applicationURL: url
        )
    }
}
