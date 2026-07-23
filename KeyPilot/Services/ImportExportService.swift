import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ImportExportService {
    func chooseImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "导入 KeyPilot 配置"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "导出 KeyPilot 配置"
        panel.nameFieldStringValue = "KeyPilot-config.json"
        panel.allowedContentTypes = [.json]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
