import Foundation

enum DiagnosticLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

struct DiagnosticEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let level: DiagnosticLevel
    let module: String
    let message: String

    init(id: UUID = UUID(), date: Date = Date(), level: DiagnosticLevel, module: String, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.module = module
        self.message = message
    }
}
