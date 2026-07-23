import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

    @ViewBuilder
    var body: some View {
        statusSection
        Divider()
        ruleCountSection
        Divider()
        settingsSection
        Divider()
        Button("退出 KeyPilot") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private var statusSection: some View {
        Label(statusText, systemImage: statusIcon)
        Button(appState.configuration.globalEnabled ? "暂停所有规则" : "恢复所有规则") {
            appState.setGlobalEnabled(!appState.configuration.globalEnabled)
        }
    }

    @ViewBuilder
    private var ruleCountSection: some View {
        Text("键位映射：\(appState.enabledRemapCount) 条启用")
        Text("软件快捷键：\(appState.enabledShortcutCount) 条启用")
        Text("连按动作：\(appState.enabledMultiPressCount) 条启用")
    }

    @ViewBuilder
    private var settingsSection: some View {
        Button("打开设置…") { appState.openSettings() }
            .keyboardShortcut(",")
        Button("权限与诊断…") { appState.openSettings() }
        Toggle("登录时启动", isOn: loginAtLaunchBinding)
    }

    private var loginAtLaunchBinding: Binding<Bool> {
        Binding(
            get: { appState.configuration.launchAtLogin },
            set: { appState.setLaunchAtLogin($0) }
        )
    }

    private var statusText: String {
        if appState.permissionState != .granted { return "缺少辅助功能权限" }
        if !appState.configuration.globalEnabled { return "所有规则已暂停" }
        return appState.eventTapStatus == .running ? "键盘规则已启用" : appState.eventTapStatus.displayName
    }

    private var statusIcon: String {
        if appState.permissionState != .granted { return "exclamationmark.triangle" }
        return appState.configuration.globalEnabled ? "checkmark.circle" : "pause.circle"
    }
}
