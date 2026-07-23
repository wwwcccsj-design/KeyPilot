import SwiftUI

struct PermissionStatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if appState.permissionState != .granted {
                    PermissionOnboardingView()
                }

                GroupBox("辅助功能权限") {
                    statusRow(
                        title: "权限状态",
                        value: appState.permissionState.displayName,
                        icon: appState.permissionState == .granted ? "checkmark.circle.fill" : "xmark.circle.fill",
                        color: appState.permissionState == .granted ? .green : .red
                    )
                    HStack {
                        Button("打开系统设置") { appState.openPermissionSettings() }
                        Button("请求并重新检查") { appState.refreshPermission(prompt: true) }
                        Button("授权后重启 KeyPilot") { appState.relaunchApplication() }
                    }
                    .padding(.top, 8)
                    Text("如果系统列表已勾选但这里仍显示未授权，请确认列表中的应用来自 ~/Applications/KeyPilot.app，然后点击“授权后重启 KeyPilot”。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                GroupBox("键盘引擎") {
                    statusRow(
                        title: "Event Tap",
                        value: appState.eventTapStatus.displayName,
                        icon: appState.eventTapStatus == .running ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        color: appState.eventTapStatus == .running ? .green : .orange
                    )
                    Divider()
                    SettingsLabeledContent("当前快照版本", value: String(appState.snapshotVersionValue))
                    SettingsLabeledContent("最近恢复尝试") {
                        Text(appState.lastEventTapRecoveryDate?.formatted(date: .abbreviated, time: .standard) ?? "本次运行暂无")
                    }
                    Button("重新启动键盘引擎") { appState.restartEngine() }
                        .padding(.top, 8)
                        .disabled(appState.permissionState != .granted)
                }

                Text("权限被撤销时，KeyPilot 会停止事件引擎并显示不可用状态。系统安全输入、登录和锁屏界面不在支持范围内。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func statusRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(value, systemImage: icon).foregroundStyle(color)
        }
        .padding(.vertical, 5)
    }
}
