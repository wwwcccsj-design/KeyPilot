import AppKit
import Foundation

@MainActor
final class ApplicationLauncher {
    private let resolver: ApplicationResolver
    private let diagnostics: DiagnosticsService

    init(resolver: ApplicationResolver = ApplicationResolver(), diagnostics: DiagnosticsService) {
        self.resolver = resolver
        self.diagnostics = diagnostics
    }

    func perform(ruleID: UUID, action: ShortcutAction) {
        switch action {
        case let .launchApplication(target):
            do {
                switch try resolver.resolve(target) {
                case let .activate(application):
                    _ = application.unhide()
                    let activated = application.activate(
                        options: [.activateAllWindows, .activateIgnoringOtherApps]
                    )
                    if !activated {
                        diagnostics.record(
                            .warning,
                            module: "Launcher",
                            message: "直接激活未生效，正在通过应用路径重新打开，规则 \(ruleID.uuidString)。"
                        )
                    }
                    // Even when activate() returns true, menu-bar and resident apps can
                    // remain without a visible window. Reopening with createsNew=false
                    // asks the app to handle a normal Dock-style reopen request.
                    open(target: target, ruleID: ruleID)
                case let .open(url):
                    open(url: url, ruleID: ruleID)
                }
            } catch {
                diagnostics.record(.error, module: "Launcher", message: "规则 \(ruleID.uuidString) 的应用不可用：\(error.localizedDescription)")
            }
        }
    }

    private func open(target: ApplicationTarget, ruleID: UUID) {
        if FileManager.default.fileExists(atPath: target.applicationURL.path) {
            open(url: target.applicationURL, ruleID: ruleID)
        } else if let bundleIdentifier = target.bundleIdentifier,
                  let resolvedURL = resolver.workspace.applicationURL(bundleIdentifier: bundleIdentifier) {
            open(url: resolvedURL, ruleID: ruleID)
        } else {
            diagnostics.record(.error, module: "Launcher", message: "应用路径失效，规则 \(ruleID.uuidString)。")
        }
    }

    private func open(url: URL, ruleID: UUID) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        resolver.workspace.openApplication(at: url, configuration: configuration) { [weak diagnostics] application, error in
            if let error {
                diagnostics?.record(.error, module: "Launcher", message: "应用启动失败，规则 \(ruleID.uuidString)：\(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    if let application {
                        _ = application.unhide()
                        _ = application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    }
                    diagnostics?.record(.info, module: "Launcher", message: "已重新打开并切换应用，规则 \(ruleID.uuidString)。")
                }
            }
        }
    }
}
