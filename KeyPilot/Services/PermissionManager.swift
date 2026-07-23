import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermissionState: String, Sendable {
    case unknown
    case denied
    case granted

    var displayName: String {
        switch self {
        case .unknown: return "正在检查"
        case .denied: return "未授权"
        case .granted: return "已授权"
        }
    }
}

final class PermissionManager {
    func currentState(promptIfNeeded: Bool = false) -> AccessibilityPermissionState {
        let trusted: Bool
        if promptIfNeeded {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        } else {
            trusted = AXIsProcessTrusted()
        }
        return trusted ? .granted : .denied
    }

    @MainActor
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
