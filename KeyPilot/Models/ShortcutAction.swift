import Foundation

enum ShortcutAction: Codable, Hashable, Sendable {
    case launchApplication(ApplicationTarget)

    var applicationTarget: ApplicationTarget {
        switch self {
        case let .launchApplication(target): return target
        }
    }
}
