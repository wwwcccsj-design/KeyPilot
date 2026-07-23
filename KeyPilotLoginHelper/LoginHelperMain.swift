import AppKit

@main
enum LoginHelperMain {
    static func main() {
        let helperURL = Bundle.main.bundleURL
        let mainApplicationURL = helperURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        _ = NSWorkspace.shared.open(mainApplicationURL)
    }
}
