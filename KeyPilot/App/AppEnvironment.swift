import Foundation

@MainActor
final class AppEnvironment {
    let diagnostics: DiagnosticsService
    let configurationStore: ConfigurationStore
    let permissionManager: PermissionManager
    let loginItemManager: LoginItemManager
    let importExportService: ImportExportService
    let applicationLauncher: ApplicationLauncher
    let triggerNotificationService: TriggerNotificationService
    let keyboardEngine: KeyboardEventEngine

    init(configurationDirectory: URL = FileLocations.applicationSupportDirectory) {
        let diagnostics = DiagnosticsService()
        self.diagnostics = diagnostics
        configurationStore = ConfigurationStore(directoryURL: configurationDirectory, diagnostics: diagnostics)
        permissionManager = PermissionManager()
        loginItemManager = LoginItemManager()
        importExportService = ImportExportService()
        applicationLauncher = ApplicationLauncher(diagnostics: diagnostics)
        triggerNotificationService = TriggerNotificationService()
        keyboardEngine = KeyboardEventEngine(diagnostics: diagnostics)
    }
}
