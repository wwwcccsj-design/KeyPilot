import AppKit
import SwiftUI

enum VisualRuleKind: String, CaseIterable {
    case remap
    case shortcut
    case multiPress

    var title: String {
        switch self {
        case .remap: return "键位映射"
        case .shortcut: return "软件快捷键"
        case .multiPress: return "连按动作"
        }
    }

    var shortTitle: String {
        switch self {
        case .remap: return "映射"
        case .shortcut: return "快捷键"
        case .multiPress: return "连按"
        }
    }

    var systemImage: String {
        switch self {
        case .remap: return "arrow.left.arrow.right"
        case .shortcut: return "command"
        case .multiPress: return "hand.tap"
        }
    }

    var color: Color {
        switch self {
        case .remap: return .blue
        case .shortcut: return .purple
        case .multiPress: return .orange
        }
    }

    var destination: SettingsDestination {
        switch self {
        case .remap: return .remaps
        case .shortcut: return .shortcuts
        case .multiPress: return .multiPress
        }
    }
}

struct VisualRuleItem: Identifiable {
    let id: UUID
    let kind: VisualRuleKind
    let trigger: String
    let action: String
    let detail: String
    let note: String?
    let applicationPath: String?
    let isEnabled: Bool

    var searchableText: String {
        [kind.title, trigger, action, detail, note ?? "", applicationPath ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    static func all(from configuration: AppConfiguration) -> [VisualRuleItem] {
        let remaps = configuration.remapRules.map { rule in
            VisualRuleItem(
                id: rule.id,
                kind: .remap,
                trigger: rule.source.displayName,
                action: rule.target.displayName,
                detail: rule.mode == .swap ? "双向交换" : "单向替换",
                note: rule.note,
                applicationPath: nil,
                isEnabled: rule.isEnabled
            )
        }
        let shortcuts = configuration.shortcutRules.map { rule in
            let target = rule.action.applicationTarget
            return VisualRuleItem(
                id: rule.id,
                kind: .shortcut,
                trigger: rule.displayShortcut,
                action: target.displayName,
                detail: rule.consumeOriginalEvent ? "打开应用 · 吞掉原事件" : "打开应用 · 保留原事件",
                note: rule.note,
                applicationPath: target.applicationURL.path,
                isEnabled: rule.isEnabled
            )
        }
        let multiPress = configuration.multiPressRules.map { rule in
            VisualRuleItem(
                id: rule.id,
                kind: .multiPress,
                trigger: rule.displayTrigger,
                action: rule.action.displayName,
                detail: "≤ \(rule.maxIntervalMilliseconds) 毫秒",
                note: rule.note,
                applicationPath: rule.action.applicationTarget?.applicationURL.path,
                isEnabled: rule.isEnabled
            )
        }
        return remaps + shortcuts + multiPress
    }
}

private enum RuleTypeFilter: String, CaseIterable {
    case all
    case remap
    case shortcut
    case multiPress

    var title: String {
        switch self {
        case .all: return "全部"
        case .remap: return "映射"
        case .shortcut: return "快捷键"
        case .multiPress: return "连按"
        }
    }

    var kind: VisualRuleKind? {
        switch self {
        case .all: return nil
        case .remap: return .remap
        case .shortcut: return .shortcut
        case .multiPress: return .multiPress
        }
    }
}

struct UnifiedRulesView: View {
    @EnvironmentObject private var appState: AppState
    let onEdit: (VisualRuleItem) -> Void
    let onCreate: (RuleCreationKind) -> Void
    @State private var searchText = ""
    @State private var typeFilter: RuleTypeFilter = .all
    @State private var enabledOnly = false
    @State private var pendingDeletion: VisualRuleItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            if filteredItems.isEmpty {
                EmptyStateView(
                    systemImage: searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                    title: searchText.isEmpty ? "还没有规则" : "没有匹配的规则",
                    message: searchText.isEmpty ? "从右上角添加第一条规则。" : "尝试清除搜索词或切换筛选条件。",
                    buttonTitle: searchText.isEmpty ? "添加键位映射" : "清除筛选"
                ) {
                    if searchText.isEmpty {
                        onCreate(.remap)
                    } else {
                        searchText = ""
                        typeFilter = .all
                        enabledOnly = false
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredItems) { item in
                            VisualRuleRow(
                                item: item,
                                onToggle: { setEnabled(item, $0) },
                                onOpen: { onEdit(item) },
                                onDuplicate: { duplicate(item) },
                                onDelete: { pendingDeletion = item }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .alert(
            "删除这条规则？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button("取消", role: .cancel) { pendingDeletion = nil }
            Button("删除", role: .destructive) {
                guard let item = pendingDeletion else { return }
                delete(item)
                pendingDeletion = nil
            }
        } message: {
            if let item = pendingDeletion {
                Text("将删除“\(item.trigger) → \(item.action)”。此操作不能撤销。")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("全部规则").font(.title2.bold())
                Text("集中查看、搜索和启停所有键位动作。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(filteredItems.count) / \(allItems.count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
            Menu {
                Button { onCreate(.remap) } label: { Label("键位映射", systemImage: "arrow.left.arrow.right") }
                Button { onCreate(.shortcut) } label: { Label("软件快捷键", systemImage: "command") }
                Button { onCreate(.multiPress) } label: { Label("连按动作", systemImage: "hand.tap") }
            } label: {
                Label("添加规则", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索按键、应用或备注", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 260, height: 30)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.quaternary))

            Picker("类型", selection: $typeFilter) {
                ForEach(RuleTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)
            Toggle("仅显示已启用", isOn: $enabledOnly)
                .toggleStyle(.checkbox)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var allItems: [VisualRuleItem] {
        VisualRuleItem.all(from: appState.configuration)
    }

    private var filteredItems: [VisualRuleItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allItems.filter { item in
            (typeFilter.kind == nil || item.kind == typeFilter.kind)
                && (!enabledOnly || item.isEnabled)
                && (query.isEmpty || item.searchableText.contains(query))
        }
    }

    private func setEnabled(_ item: VisualRuleItem, _ enabled: Bool) {
        switch item.kind {
        case .remap: appState.setRemapEnabled(id: item.id, enabled: enabled)
        case .shortcut: appState.setShortcutEnabled(id: item.id, enabled: enabled)
        case .multiPress: appState.setMultiPressEnabled(id: item.id, enabled: enabled)
        }
    }

    private func duplicate(_ item: VisualRuleItem) {
        switch item.kind {
        case .remap: appState.duplicateRemap(id: item.id)
        case .shortcut: appState.duplicateShortcut(id: item.id)
        case .multiPress: appState.duplicateMultiPress(id: item.id)
        }
    }

    private func delete(_ item: VisualRuleItem) {
        switch item.kind {
        case .remap: appState.removeRemap(id: item.id)
        case .shortcut: appState.removeShortcut(id: item.id)
        case .multiPress: appState.removeMultiPress(id: item.id)
        }
    }
}

struct VisualRuleRow: View {
    let item: VisualRuleItem
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { item.isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(item.kind.color.opacity(0.13))
                Image(systemName: item.kind.systemImage)
                    .foregroundStyle(item.kind.color)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.kind.shortTitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(item.kind.color)
                Text(item.trigger)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.caption).foregroundStyle(.tertiary)
            if let applicationPath = item.applicationPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: applicationPath))
                    .resizable().frame(width: 28, height: 28)
            } else {
                Text(item.action)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .frame(minWidth: 44)
            }
            VStack(alignment: .leading, spacing: 3) {
                if item.applicationPath != nil {
                    Text(item.action).fontWeight(.medium)
                }
                Text(item.note.flatMap { $0.isEmpty ? nil : $0 } ?? item.detail)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.isEnabled ? "已启用" : "已停用")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.isEnabled ? Color.green : Color.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((item.isEnabled ? Color.green : Color.secondary).opacity(0.1), in: Capsule())
            Button("编辑", action: onOpen).buttonStyle(.bordered)
            Menu {
                Button(action: onDuplicate) { Label("创建停用副本", systemImage: "plus.square.on.square") }
                Divider()
                Button(role: .destructive, action: onDelete) { Label("删除规则", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.quaternary))
        .opacity(item.isEnabled ? 1 : 0.68)
    }
}
