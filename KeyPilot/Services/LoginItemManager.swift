import Foundation
import ServiceManagement

private enum LoginItemStateError: LocalizedError {
    case requiresApproval
    case legacyRegistrationFailed

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return "登录项需要用户在“系统设置 → 通用 → 登录项”中批准。"
        case .legacyRegistrationFailed:
            return "无法注册兼容模式登录项，请确认 KeyPilot 位于固定路径并已正确签名。"
        }
    }
}

@MainActor
final class LoginItemManager {
    private let legacyHelperIdentifier = "com.keypilot.mac.loginhelper" as CFString
    private var legacyState = false

    func synchronize(fallback: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        legacyState = fallback
        return legacyState
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        if SMAppService.mainApp.status == .requiresApproval {
                            throw LoginItemStateError.requiresApproval
                        }
                    }
                } else if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            } else {
                guard SMLoginItemSetEnabled(legacyHelperIdentifier, enabled) else {
                    throw LoginItemStateError.legacyRegistrationFailed
                }
                legacyState = enabled
            }
        } catch {
            throw KeyPilotError.loginItemRegistrationFailed(error)
        }
    }
}
