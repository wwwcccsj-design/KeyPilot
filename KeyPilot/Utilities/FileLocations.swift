import Foundation

enum FileLocations {
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyPilot", isDirectory: true)
    }
}
