import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var configuration: AppConfiguration = .default
    @Published private(set) var permissionState: AccessibilityPermissionState = .unknown
    @Published private(set) var eventTapStatus: EventTapStatus = .stopped
    @Published private(set) var lastEventTapRecoveryDate: Date?
    @Published private(set) var diagnosticEvents: [DiagnosticEvent] = []
    @Published var presentedError: String?
    var settingsPresenter: (() -> Void)?

    let environment: AppEnvironment
    private let compiler = RuleCompiler()
    private var snapshotVersion: UInt64 = 0
    private var permissionTimer: Timer?
    private var hasStarted = false

    init(environment: AppEnvironment) {
        self.environment = environment
        environment.diagnostics.onChange = { [weak self] events in
            self?.diagnosticEvents = events
        }
        environment.keyboardEngine.onStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.eventTapStatus = status
                if case .recovering = status { self?.lastEventTapRecoveryDate = Date() }
            }
        }
        environment.keyboardEngine.onAction = { [weak self] ruleID, action in
            DispatchQueue.main.async {
                guard let self else { return }
                self.environment.applicationLauncher.perform(ruleID: ruleID, action: action)
                if self.configuration.showTriggerNotification {
                    self.environment.triggerNotificationService.show(for: action)
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak environment] _ in
            environment?.keyboardEngine.stop()
        }
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in self.restartEngine() }
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        do {
            configuration = try environment.configurationStore.load()
            let actualLoginState = environment.loginItemManager.synchronize(
                fallback: configuration.launchAtLogin
            )
            if configuration.launchAtLogin != actualLoginState {
                configuration.launchAtLogin = actualLoginState
                try environment.configurationStore.save(configuration)
            }
        } catch {
            presentedError = error.localizedDescription
            environment.diagnostics.record(.error, module: "Startup", message: error.localizedDescription)
        }
        diagnosticEvents = environment.diagnostics.currentEvents()
        refreshPermission(prompt: false)
        compileAndApply()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in self.refreshPermission(prompt: false) }
        }

        if permissionState != .granted,
           !UserDefaults.standard.bool(forKey: "hasShownPermissionOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasShownPermissionOnboarding")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openSettings() }
        }
    }

    var enabledRemapCount: Int { configuration.remapRules.filter(\.isEnabled).count }
    var enabledShortcutCount: Int { configuration.shortcutRules.filter(\.isEnabled).count }
    var enabledMultiPressCount: Int { configuration.multiPressRules.filter(\.isEnabled).count }
    var isOperational: Bool { permissionState == .granted && eventTapStatus == .running && configuration.globalEnabled }
    var snapshotVersionValue: UInt64 { snapshotVersion }

    var menuBarIconName: String {
        if permissionState != .granted { return "keyboard.badge.exclamationmark" }
        if case .failed = eventTapStatus { return "exclamationmark.triangle.fill" }
        return configuration.globalEnabled ? "keyboard" : "pause.circle"
    }

    func setGlobalEnabled(_ enabled: Bool) {
        updateConfiguration { $0.globalEnabled = enabled }
    }

    func upsertRemap(_ rule: RemapRule) throws {
        var candidate = configuration
        if let index = candidate.remapRules.firstIndex(where: { $0.id == rule.id }) {
            candidate.remapRules[index] = rule
        } else {
            candidate.remapRules.append(rule)
        }
        try commit(candidate)
    }

    func removeRemap(id: UUID) {
        updateConfiguration { $0.remapRules.removeAll { $0.id == id } }
    }

    func setRemapEnabled(id: UUID, enabled: Bool) {
        updateConfiguration {
            guard let index = $0.remapRules.firstIndex(where: { $0.id == id }) else { return }
            $0.remapRules[index].isEnabled = enabled
        }
    }

    func upsertShortcut(_ rule: ShortcutRule) throws {
        var candidate = configuration
        if let index = candidate.shortcutRules.firstIndex(where: { $0.id == rule.id }) {
            candidate.shortcutRules[index] = rule
        } else {
            candidate.shortcutRules.append(rule)
        }
        try commit(candidate)
    }

    func removeShortcut(id: UUID) {
        updateConfiguration { $0.shortcutRules.removeAll { $0.id == id } }
    }

    func setShortcutEnabled(id: UUID, enabled: Bool) {
        updateConfiguration {
            guard let index = $0.shortcutRules.firstIndex(where: { $0.id == id }) else { return }
            $0.shortcutRules[index].isEnabled = enabled
        }
    }

    func upsertMultiPress(_ rule: MultiPressRule) throws {
        var candidate = configuration
        if let index = candidate.multiPressRules.firstIndex(where: { $0.id == rule.id }) {
            candidate.multiPressRules[index] = rule
        } else {
            candidate.multiPressRules.append(rule)
        }
        try commit(candidate)
    }

    func removeMultiPress(id: UUID) {
        updateConfiguration { $0.multiPressRules.removeAll { $0.id == id } }
    }

    func setMultiPressEnabled(id: UUID, enabled: Bool) {
        updateConfiguration {
            guard let index = $0.multiPressRules.firstIndex(where: { $0.id == id }) else { return }
            $0.multiPressRules[index].isEnabled = enabled
        }
    }

    func duplicateRemap(id: UUID) {
        guard let rule = configuration.remapRules.first(where: { $0.id == id }) else { return }
        updateConfiguration {
            $0.remapRules.append(RemapRule(
                source: rule.source,
                target: rule.target,
                mode: rule.mode,
                isEnabled: false,
                note: duplicateNote(rule.note)
            ))
        }
    }

    func duplicateShortcut(id: UUID) {
        guard let rule = configuration.shortcutRules.first(where: { $0.id == id }) else { return }
        updateConfiguration {
            $0.shortcutRules.append(ShortcutRule(
                key: rule.key,
                modifiers: rule.modifiers,
                action: rule.action,
                consumeOriginalEvent: rule.consumeOriginalEvent,
                isEnabled: false,
                note: duplicateNote(rule.note)
            ))
        }
    }

    func duplicateMultiPress(id: UUID) {
        guard let rule = configuration.multiPressRules.first(where: { $0.id == id }) else { return }
        updateConfiguration {
            $0.multiPressRules.append(MultiPressRule(
                source: rule.source,
                pressCount: rule.pressCount,
                maxIntervalMilliseconds: rule.maxIntervalMilliseconds,
                action: rule.action,
                isEnabled: false,
                note: duplicateNote(rule.note)
            ))
        }
    }

    func setShowTriggerNotification(_ enabled: Bool) {
        if enabled { environment.triggerNotificationService.requestAuthorization() }
        updateConfiguration { $0.showTriggerNotification = enabled }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try environment.loginItemManager.setEnabled(enabled)
            var candidate = configuration
            candidate.launchAtLogin = environment.loginItemManager.synchronize(fallback: enabled)
            try commit(candidate)
        } catch {
            presentedError = error.localizedDescription
            environment.diagnostics.record(.error, module: "LoginItem", message: error.localizedDescription)
        }
    }

    func refreshPermission(prompt: Bool) {
        let previous = permissionState
        permissionState = environment.permissionManager.currentState(promptIfNeeded: prompt)
        guard previous != permissionState else { return }
        environment.diagnostics.record(
            .info,
            module: "Permission",
            message: "辅助功能权限状态变为：\(permissionState.displayName)。"
        )
        if permissionState == .granted {
            startEngineIfNeeded()
        } else {
            environment.keyboardEngine.stop()
        }
    }

    func openPermissionSettings() {
        environment.permissionManager.openSystemSettings()
    }

    func relaunchApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error {
                    self?.presentedError = "重新启动失败：\(error.localizedDescription)"
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func restartEngine() {
        guard permissionState == .granted else {
            presentedError = KeyPilotError.accessibilityPermissionMissing.localizedDescription
            return
        }
        do {
            try environment.keyboardEngine.restart()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func importConfiguration() {
        guard let url = environment.importExportService.chooseImportURL() else { return }
        do {
            let candidate = try environment.configurationStore.validateImport(from: url)
            let alert = NSAlert()
            alert.messageText = "替换当前配置？"
            alert.informativeText = "导入将替换当前的全部映射和快捷键规则。此操作会在保存后更新备份。"
            alert.addButton(withTitle: "导入")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            try commit(candidate)
            environment.diagnostics.record(.info, module: "Configuration", message: "已导入配置。")
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func exportConfiguration() {
        guard let url = environment.importExportService.chooseExportURL() else { return }
        do {
            try environment.configurationStore.export(configuration, to: url)
            environment.diagnostics.record(.info, module: "Configuration", message: "已导出配置。")
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func clearDiagnostics() {
        environment.diagnostics.clear()
    }

    func openSettings() {
        settingsPresenter?()
    }

    private func updateConfiguration(_ mutation: (inout AppConfiguration) -> Void) {
        var candidate = configuration
        mutation(&candidate)
        do {
            try commit(candidate)
        } catch {
            presentedError = error.localizedDescription
            environment.diagnostics.record(.error, module: "Configuration", message: error.localizedDescription)
        }
    }

    private func duplicateNote(_ note: String?) -> String {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "副本（默认停用）" : "\(trimmed) · 副本（默认停用）"
    }

    private func commit(_ candidate: AppConfiguration) throws {
        try ConflictValidator.validate(candidate)
        try environment.configurationStore.save(candidate)
        configuration = candidate
        compileAndApply()
    }

    private func compileAndApply() {
        do {
            snapshotVersion &+= 1
            let snapshot = try compiler.compile(configuration, version: snapshotVersion)
            environment.keyboardEngine.update(snapshot: snapshot, globalEnabled: configuration.globalEnabled)
            startEngineIfNeeded()
        } catch {
            presentedError = error.localizedDescription
            environment.diagnostics.record(.error, module: "Rules", message: error.localizedDescription)
        }
    }

    private func startEngineIfNeeded() {
        guard permissionState == .granted else { return }
        if eventTapStatus == .running || {
            if case .recovering = eventTapStatus { return true }
            return false
        }() { return }
        do {
            try environment.keyboardEngine.start()
        } catch {
            presentedError = error.localizedDescription
        }
    }
}
