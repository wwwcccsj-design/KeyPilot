import Foundation

enum KeyPilotError: LocalizedError {
    case accessibilityPermissionMissing
    case eventTapCreationFailed
    case eventTapEnableFailed
    case invalidRule(String)
    case conflictingRule(String)
    case configurationReadFailed(Error)
    case configurationWriteFailed(Error)
    case unsupportedSchema(Int)
    case applicationNotFound
    case applicationLaunchFailed(Error)
    case loginItemRegistrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing: return "缺少辅助功能权限。"
        case .eventTapCreationFailed: return "无法创建键盘事件监听器。"
        case .eventTapEnableFailed: return "无法恢复键盘事件监听器。"
        case let .invalidRule(message): return "规则无效：\(message)"
        case let .conflictingRule(message): return "规则冲突：\(message)"
        case let .configurationReadFailed(error): return "读取配置失败：\(error.localizedDescription)"
        case let .configurationWriteFailed(error): return "写入配置失败：\(error.localizedDescription)"
        case let .unsupportedSchema(version): return "不支持配置版本 \(version)。"
        case .applicationNotFound: return "找不到所选应用，请重新选择。"
        case let .applicationLaunchFailed(error): return "启动应用失败：\(error.localizedDescription)"
        case let .loginItemRegistrationFailed(error): return "修改登录项失败：\(error.localizedDescription)"
        }
    }
}
