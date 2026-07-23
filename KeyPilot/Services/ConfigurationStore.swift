import Foundation

final class ConfigurationStore {
    let directoryURL: URL
    let configurationURL: URL
    let backupURL: URL
    private let fileManager: FileManager
    private let diagnostics: DiagnosticsService?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURL: URL = FileLocations.applicationSupportDirectory,
        fileManager: FileManager = .default,
        diagnostics: DiagnosticsService? = nil
    ) {
        self.directoryURL = directoryURL
        configurationURL = directoryURL.appendingPathComponent("config.json")
        backupURL = directoryURL.appendingPathComponent("config.backup.json")
        self.fileManager = fileManager
        self.diagnostics = diagnostics
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> AppConfiguration {
        try createDirectoryIfNeeded()
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            let configuration = AppConfiguration.default
            try save(configuration)
            diagnostics?.record(.info, module: "Configuration", message: "已创建默认配置。")
            return configuration
        }

        do {
            return try readAndValidate(from: configurationURL)
        } catch {
            diagnostics?.record(.warning, module: "Configuration", message: "正式配置损坏，正在尝试备份恢复。")
            do {
                let recovered = try readAndValidate(from: backupURL)
                try save(recovered)
                diagnostics?.record(.info, module: "Configuration", message: "配置已从备份恢复。")
                return recovered
            } catch let backupError {
                diagnostics?.record(.error, module: "Configuration", message: "配置与备份均不可用，已载入安全默认配置。")
                archiveCorruptFile(at: configurationURL)
                archiveCorruptFile(at: backupURL)
                let fallback = AppConfiguration.default
                do { try save(fallback) } catch {
                    throw KeyPilotError.configurationReadFailed(backupError)
                }
                return fallback
            }
        }
    }

    func save(_ configuration: AppConfiguration) throws {
        do {
            try ConflictValidator.validate(configuration)
            try createDirectoryIfNeeded()
            let data = try encoder.encode(configuration)
            let decoded = try decoder.decode(AppConfiguration.self, from: data)
            try ConflictValidator.validate(decoded)
            try data.write(to: configurationURL, options: [.atomic])
            let persisted = try Data(contentsOf: configurationURL)
            let persistedConfiguration = try decoder.decode(AppConfiguration.self, from: persisted)
            try ConflictValidator.validate(persistedConfiguration)
            try data.write(to: backupURL, options: [.atomic])
        } catch let error as KeyPilotError {
            throw error
        } catch {
            throw KeyPilotError.configurationWriteFailed(error)
        }
    }

    func validateImport(from url: URL) throws -> AppConfiguration {
        do {
            return try readAndValidate(from: url)
        } catch let error as KeyPilotError {
            throw error
        } catch {
            throw KeyPilotError.configurationReadFailed(error)
        }
    }

    func export(_ configuration: AppConfiguration, to url: URL) throws {
        do {
            try ConflictValidator.validate(configuration)
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: [.atomic])
        } catch let error as KeyPilotError {
            throw error
        } catch {
            throw KeyPilotError.configurationWriteFailed(error)
        }
    }

    private func readAndValidate(from url: URL) throws -> AppConfiguration {
        let data = try Data(contentsOf: url)
        let configuration = try decoder.decode(AppConfiguration.self, from: data)
        try ConflictValidator.validate(configuration)
        return configuration
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func archiveCorruptFile(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let archivedURL = directoryURL.appendingPathComponent(
            "\(url.deletingPathExtension().lastPathComponent).corrupt-\(UUID().uuidString).json"
        )
        do {
            try fileManager.moveItem(at: url, to: archivedURL)
            diagnostics?.record(
                .warning,
                module: "Configuration",
                message: "损坏文件已保留为 \(archivedURL.lastPathComponent)。"
            )
        } catch {
            diagnostics?.record(
                .error,
                module: "Configuration",
                message: "无法保留损坏配置：\(error.localizedDescription)"
            )
        }
    }
}
