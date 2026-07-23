import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable {
    case dashboard
    case allRules
    case remaps
    case shortcuts
    case multiPress
    case permission
    case general
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "概览"
        case .allRules: return "全部规则"
        case .remaps: return "键位映射"
        case .shortcuts: return "软件快捷键"
        case .multiPress: return "连按动作"
        case .permission: return "权限与状态"
        case .general: return "通用设置"
        case .diagnostics: return "日志与诊断"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .allRules: return "list.bullet.rectangle"
        case .remaps: return "arrow.left.arrow.right"
        case .shortcuts: return "command"
        case .multiPress: return "hand.tap"
        case .permission: return "checkmark.shield"
        case .general: return "gearshape"
        case .diagnostics: return "stethoscope"
        }
    }
}

enum RuleCreationKind {
    case remap
    case shortcut
    case multiPress

    var destination: SettingsDestination {
        switch self {
        case .remap: return .remaps
        case .shortcut: return .shortcuts
        case .multiPress: return .multiPress
        }
    }
}

private struct RuleCreationRequest {
    let id = UUID()
    let kind: RuleCreationKind
}

private struct RuleEditingRequest {
    let ruleID: UUID
    let kind: VisualRuleKind
}

struct SettingsRootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SettingsDestination = .dashboard
    @State private var creationRequest: RuleCreationRequest?
    @State private var editingRequest: RuleEditingRequest?

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: 205)
            Divider()
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 600)
        .alert(
            "KeyPilot",
            isPresented: Binding(
                get: { appState.presentedError != nil },
                set: { if !$0 { appState.presentedError = nil } }
            )
        ) {
            Button("好", role: .cancel) { appState.presentedError = nil }
        } message: {
            Text(appState.presentedError ?? "发生未知错误。")
        }
    }

    private var settingsSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("KeyPilot").font(.headline)
                    Text("可视化控制台").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sidebarSection("工作台", items: [.dashboard, .allRules])
                    sidebarSection("规则", items: [.remaps, .shortcuts, .multiPress])
                    sidebarSection("系统", items: [.permission, .general, .diagnostics])
                }
                .padding(.horizontal, 9)
                .padding(.bottom, 12)
            }

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(operationalColor).frame(width: 8, height: 8)
                    Text(operationalText).font(.caption).fontWeight(.medium)
                    Spacer()
                }
                Toggle(
                    appState.configuration.globalEnabled ? "规则总开关已开启" : "规则总开关已暂停",
                    isOn: Binding(
                        get: { appState.configuration.globalEnabled },
                        set: { appState.setGlobalEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .font(.caption)
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    @ViewBuilder
    private func sidebarSection(_ title: String, items: [SettingsDestination]) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 9)
            .padding(.top, 12)
            .padding(.bottom, 3)
        ForEach(items) { item in
            Button {
                selection = item
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: item.systemImage)
                        .frame(width: 18)
                    Text(item.title)
                    Spacer()
                    if let count = count(for: item), count > 0 {
                        Text(String(count))
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .font(.system(size: 13, weight: selection == item ? .semibold : .regular))
                .foregroundStyle(selection == item ? Color.accentColor : Color.primary)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(
                    selection == item ? Color.accentColor.opacity(0.13) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            VisualDashboardView(
                onNavigate: { selection = $0 },
                onCreate: requestCreation
            )
        case .allRules:
            UnifiedRulesView(
                onEdit: requestEditing,
                onCreate: requestCreation
            )
        case .remaps:
            RemapRulesView(
                creationRequestID: creationRequest?.kind.destination == .remaps ? creationRequest?.id : nil,
                onCreationRequestHandled: { creationRequest = nil },
                editingRequestRuleID: editingRequest?.kind == .remap ? editingRequest?.ruleID : nil,
                onEditingRequestHandled: { editingRequest = nil }
            )
        case .shortcuts:
            ShortcutRulesView(
                creationRequestID: creationRequest?.kind.destination == .shortcuts ? creationRequest?.id : nil,
                onCreationRequestHandled: { creationRequest = nil },
                editingRequestRuleID: editingRequest?.kind == .shortcut ? editingRequest?.ruleID : nil,
                onEditingRequestHandled: { editingRequest = nil }
            )
        case .multiPress:
            MultiPressRulesView(
                creationRequestID: creationRequest?.kind.destination == .multiPress ? creationRequest?.id : nil,
                onCreationRequestHandled: { creationRequest = nil },
                editingRequestRuleID: editingRequest?.kind == .multiPress ? editingRequest?.ruleID : nil,
                onEditingRequestHandled: { editingRequest = nil }
            )
        case .permission:
            PermissionStatusView()
        case .general:
            GeneralSettingsView()
        case .diagnostics:
            DiagnosticsView()
        }
    }

    private func requestCreation(_ kind: RuleCreationKind) {
        editingRequest = nil
        creationRequest = RuleCreationRequest(kind: kind)
        selection = kind.destination
    }

    private func requestEditing(_ item: VisualRuleItem) {
        creationRequest = nil
        editingRequest = RuleEditingRequest(ruleID: item.id, kind: item.kind)
        selection = item.kind.destination
    }

    private func count(for destination: SettingsDestination) -> Int? {
        switch destination {
        case .allRules:
            return appState.configuration.remapRules.count
                + appState.configuration.shortcutRules.count
                + appState.configuration.multiPressRules.count
        case .remaps: return appState.configuration.remapRules.count
        case .shortcuts: return appState.configuration.shortcutRules.count
        case .multiPress: return appState.configuration.multiPressRules.count
        default: return nil
        }
    }

    private var operationalText: String {
        if appState.permissionState != .granted { return "需要辅助功能权限" }
        if !appState.configuration.globalEnabled { return "所有规则已暂停" }
        return appState.eventTapStatus == .running ? "键盘引擎运行中" : appState.eventTapStatus.displayName
    }

    private var operationalColor: Color {
        appState.isOperational ? .green : (appState.permissionState == .granted ? .orange : .red)
    }
}
