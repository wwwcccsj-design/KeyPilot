import Foundation

enum RemapMode: String, Codable, CaseIterable, Sendable {
    case oneWay
    case swap

    var displayName: String { self == .oneWay ? "单向替换" : "双向交换" }
    var symbol: String { self == .oneWay ? "→" : "↔" }
}

struct RemapRule: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var source: KeyDescriptor
    var target: KeyDescriptor
    var mode: RemapMode
    var isEnabled: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        source: KeyDescriptor,
        target: KeyDescriptor,
        mode: RemapMode = .oneWay,
        isEnabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.mode = mode
        self.isEnabled = isEnabled
        self.note = note
    }
}
