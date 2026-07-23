import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("运行") {
                Toggle(
                    "启用全部规则",
                    isOn: Binding(
                        get: { appState.configuration.globalEnabled },
                        set: { appState.setGlobalEnabled($0) }
                    )
                )
                Toggle(
                    "登录时启动",
                    isOn: Binding(
                        get: { appState.configuration.launchAtLogin },
                        set: { appState.setLaunchAtLogin($0) }
                    )
                )
                Toggle(
                    "触发软件快捷键时显示通知",
                    isOn: Binding(
                        get: { appState.configuration.showTriggerNotification },
                        set: { appState.setShowTriggerNotification($0) }
                    )
                )
            }

            Section("配置") {
                SettingsLabeledContent("配置位置") {
                    Text("~/Library/Application Support/KeyPilot/config.json")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                HStack {
                    Button("导入配置…") { appState.importConfiguration() }
                    Button("导出配置…") { appState.exportConfiguration() }
                }
            }

            Section("隐私") {
                Text("KeyPilot 仅匹配配置所需的虚拟键码，不保存按键历史、输入文字或密码，不进行网络通信。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
