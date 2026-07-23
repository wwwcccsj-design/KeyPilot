import SwiftUI

struct VisualDashboardView: View {
    @EnvironmentObject private var appState: AppState
    let onNavigate: (SettingsDestination) -> Void
    let onCreate: (RuleCreationKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dashboardHeader
                statistics
                quickCreate
                HStack(alignment: .top, spacing: 16) {
                    recentRules
                    systemHealth
                        .frame(width: 285)
                }
            }
            .padding(24)
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("KeyPilot 控制台")
                    .font(.system(size: 28, weight: .bold))
                Text("用可视化规则控制你的键盘和应用。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 9, height: 9)
                Text(statusText).font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(statusColor.opacity(0.11), in: Capsule())
            Button {
                appState.setGlobalEnabled(!appState.configuration.globalEnabled)
            } label: {
                Label(
                    appState.configuration.globalEnabled ? "暂停全部" : "启用全部",
                    systemImage: appState.configuration.globalEnabled ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statistics: some View {
        HStack(spacing: 12) {
            DashboardStatCard(
                title: "键位映射",
                value: appState.enabledRemapCount,
                total: appState.configuration.remapRules.count,
                systemImage: "arrow.left.arrow.right",
                color: .blue
            ) { onNavigate(.remaps) }
            DashboardStatCard(
                title: "软件快捷键",
                value: appState.enabledShortcutCount,
                total: appState.configuration.shortcutRules.count,
                systemImage: "command",
                color: .purple
            ) { onNavigate(.shortcuts) }
            DashboardStatCard(
                title: "连按动作",
                value: appState.enabledMultiPressCount,
                total: appState.configuration.multiPressRules.count,
                systemImage: "hand.tap",
                color: .orange
            ) { onNavigate(.multiPress) }
        }
    }

    private var quickCreate: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("快速创建").font(.headline)
                Spacer()
                Button("查看全部规则") { onNavigate(.allRules) }
                    .buttonStyle(.plain).foregroundStyle(Color.accentColor)
            }
            HStack(spacing: 10) {
                QuickCreateCard(
                    title: "替换或交换按键",
                    subtitle: "A → B、B ↔ ]",
                    systemImage: "arrow.left.arrow.right",
                    color: .blue
                ) { onCreate(.remap) }
                QuickCreateCard(
                    title: "组合键打开应用",
                    subtitle: "⌘⌥C → Chrome",
                    systemImage: "command",
                    color: .purple
                ) { onCreate(.shortcut) }
                QuickCreateCard(
                    title: "连按触发动作",
                    subtitle: "Space × 3 → 微信",
                    systemImage: "hand.tap",
                    color: .orange
                ) { onCreate(.multiPress) }
            }
        }
    }

    private var recentRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前规则").font(.headline)
                Spacer()
                Text("\(allItems.count) 条").font(.caption).foregroundStyle(.secondary)
            }
            if allItems.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "sparkles").font(.title).foregroundStyle(Color.accentColor)
                    Text("还没有规则").fontWeight(.semibold)
                    Text("从上方选择一种动作开始。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(allItems.prefix(5))) { item in
                        DashboardRuleRow(item: item) {
                            onNavigate(item.kind.destination)
                        }
                    }
                    if allItems.count > 5 {
                        Button("查看另外 \(allItems.count - 5) 条规则") { onNavigate(.allRules) }
                            .buttonStyle(.plain).foregroundStyle(Color.accentColor).padding(.top, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemHealth: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("系统状态").font(.headline)
                Spacer()
                Image(systemName: appState.isOperational ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(appState.isOperational ? Color.green : Color.orange)
            }
            HealthRow(
                title: "辅助功能权限",
                value: appState.permissionState.displayName,
                statusColor: appState.permissionState == .granted ? .green : .orange
            )
            Divider()
            HealthRow(
                title: "键盘引擎",
                value: appState.eventTapStatus.displayName,
                statusColor: appState.eventTapStatus == .running ? .green : .orange
            )
            Divider()
            HealthRow(
                title: "登录时启动",
                value: appState.configuration.launchAtLogin ? "已开启" : "未开启",
                statusColor: .secondary
            )
            Button {
                onNavigate(.permission)
            } label: {
                HStack {
                    Text("检查权限与引擎")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }

    private var allItems: [VisualRuleItem] {
        VisualRuleItem.all(from: appState.configuration)
    }

    private var statusText: String {
        if appState.permissionState != .granted { return "需要授权" }
        if !appState.configuration.globalEnabled { return "已暂停" }
        return appState.eventTapStatus == .running ? "运行中" : appState.eventTapStatus.displayName
    }

    private var statusColor: Color {
        appState.isOperational ? .green : (appState.permissionState == .granted ? .orange : .red)
    }
}

private struct DashboardStatCard: View {
    let title: String
    let value: Int
    let total: Int
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.13))
                    Image(systemName: systemImage).font(.title3).foregroundStyle(color)
                }
                .frame(width: 43, height: 43)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(value)).font(.title2.bold()).monospacedDigit()
                        Text("/ \(total)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickCreateCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.title3).foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundStyle(color)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(color.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardRuleRow: View {
    let item: VisualRuleItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.kind.systemImage)
                    .foregroundStyle(item.kind.color)
                    .frame(width: 28, height: 28)
                    .background(item.kind.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                Text(item.trigger).font(.system(.callout, design: .monospaced).weight(.semibold))
                    .frame(width: 100, alignment: .leading).lineLimit(1)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                Text(item.action).font(.callout).lineLimit(1)
                Spacer()
                Circle().fill(item.isEnabled ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 47)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.quaternary))
        }
        .buttonStyle(.plain)
    }
}

private struct HealthRow: View {
    let title: String
    let value: String
    let statusColor: Color

    var body: some View {
        HStack {
            Text(title).font(.callout)
            Spacer()
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
