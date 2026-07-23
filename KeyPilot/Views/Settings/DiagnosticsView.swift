import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("日志与诊断").font(.title2.bold())
                    Text("最多保留本次运行的 100 条安全状态事件，不包含按键内容。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("清空") { appState.clearDiagnostics() }
                    .disabled(appState.diagnosticEvents.isEmpty)
                Button("重启引擎") { appState.restartEngine() }
            }

            if appState.diagnosticEvents.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.shield",
                    title: "暂无诊断事件",
                    message: "KeyPilot 不会记录原始按键或用户输入。",
                    buttonTitle: "重新检查权限"
                ) { appState.refreshPermission(prompt: false) }
            } else {
                List(appState.diagnosticEvents) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: event.level))
                            .foregroundStyle(color(for: event.level))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(event.module).fontWeight(.semibold)
                                Spacer()
                                Text(event.date.formatted(date: .omitted, time: .standard))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(event.message).textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func icon(for level: DiagnosticLevel) -> String {
        switch level {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private func color(for level: DiagnosticLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}
