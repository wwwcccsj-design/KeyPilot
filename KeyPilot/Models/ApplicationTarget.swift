import Foundation

struct ApplicationTarget: Codable, Hashable, Sendable {
    var displayName: String
    var bundleIdentifier: String?
    var applicationURL: URL
}
