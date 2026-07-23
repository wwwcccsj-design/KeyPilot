// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "KeyPilot",
    platforms: [.macOS(.v12)],
    products: [.library(name: "KeyPilot", targets: ["KeyPilot"])],
    targets: [
        .target(
            name: "KeyPilot",
            path: "KeyPilot",
            sources: [
                "Core",
                "Models",
                "Services/ApplicationLauncher.swift",
                "Services/ApplicationResolver.swift",
                "Services/ConfigurationStore.swift",
                "Services/DiagnosticsService.swift",
                "Services/KeyboardLayoutService.swift",
                "Utilities/AtomicBox.swift",
                "Utilities/FileLocations.swift",
                "Utilities/KeyCodeNames.swift"
            ]
        ),
        .testTarget(name: "KeyPilotTests", dependencies: ["KeyPilot"], path: "KeyPilotTests")
    ]
)
