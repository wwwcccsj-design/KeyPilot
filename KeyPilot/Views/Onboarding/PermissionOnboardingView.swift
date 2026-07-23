import SwiftUI

struct PermissionOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("需要辅助功能权限", systemImage: "hand.raised.fill")
                .font(.title2.bold())
            Text("KeyPilot 需要辅助功能权限，才能在其他应用中识别和修改键盘事件。")
            Text("KeyPilot 不保存您输入的文字，不上传键盘数据。")
                .foregroundStyle(.secondary)
            HStack {
                Button("打开系统设置") { appState.openPermissionSettings() }
                    .buttonStyle(.borderedProminent)
                Button("重新检查") { appState.refreshPermission(prompt: false) }
            }
        }
        .padding(18)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}
