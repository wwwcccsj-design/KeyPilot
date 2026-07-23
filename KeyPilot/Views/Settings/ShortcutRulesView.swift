import AppKit
import SwiftUI

struct ShortcutRulesView: View {
    @EnvironmentObject private var appState: AppState
    let creationRequestID: UUID?
    let onCreationRequestHandled: () -> Void
    let editingRequestRuleID: UUID?
    let onEditingRequestHandled: () -> Void
    @State private var editorPresentation: RuleEditorPresentation<ShortcutRule>?

    init(
        creationRequestID: UUID? = nil,
        onCreationRequestHandled: @escaping () -> Void = {},
        editingRequestRuleID: UUID? = nil,
        onEditingRequestHandled: @escaping () -> Void = {}
    ) {
        self.creationRequestID = creationRequestID
        self.onCreationRequestHandled = onCreationRequestHandled
        self.editingRequestRuleID = editingRequestRuleID
        self.onEditingRequestHandled = onEditingRequestHandled
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("软件快捷键").font(.title2.bold())
                    Text("使用带修饰键的全局组合键启动或激活应用。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                } label: {
                    Label("添加快捷键", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.configuration.shortcutRules.isEmpty {
                EmptyStateView(
                    systemImage: "command",
                    title: "还没有软件快捷键",
                    message: "录入一个组合键，再选择需要打开或切换到前台的应用。",
                    buttonTitle: "添加软件快捷键"
                ) {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                }
            } else {
                List {
                    ForEach(appState.configuration.shortcutRules) { rule in
                        ShortcutRuleRow(rule: rule) {
                            appState.setShortcutEnabled(id: rule.id, enabled: $0)
                        } onEdit: {
                            editorPresentation = RuleEditorPresentation(rule: rule)
                        } onDelete: {
                            appState.removeShortcut(id: rule.id)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $editorPresentation) { presentation in
            ShortcutRuleEditor(rule: presentation.rule) { rule in
                try appState.upsertShortcut(rule)
            }
        }
        .onAppear {
            handleCreationRequest()
            handleEditingRequest()
        }
        .onChange(of: creationRequestID) { _ in handleCreationRequest() }
        .onChange(of: editingRequestRuleID) { _ in handleEditingRequest() }
    }

    private func handleCreationRequest() {
        guard creationRequestID != nil else { return }
        DispatchQueue.main.async {
            editorPresentation = RuleEditorPresentation(rule: nil)
            onCreationRequestHandled()
        }
    }

    private func handleEditingRequest() {
        guard let ruleID = editingRequestRuleID,
              let rule = appState.configuration.shortcutRules.first(where: { $0.id == ruleID }) else { return }
        DispatchQueue.main.async {
            editorPresentation = RuleEditorPresentation(rule: rule)
            onEditingRequestHandled()
        }
    }
}

private struct ShortcutRuleRow: View {
    let rule: ShortcutRule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let target = rule.action.applicationTarget
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: onToggle)).labelsHidden()
            Image(nsImage: NSWorkspace.shared.icon(forFile: target.applicationURL.path))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.displayName).fontWeight(.medium)
                Text(target.applicationURL.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(rule.displayShortcut)
                .font(.system(.body, design: .monospaced).bold())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            Text(rule.consumeOriginalEvent ? "吞掉原事件" : "保留原事件")
                .font(.caption).foregroundStyle(.secondary)
            if isTargetResolvable(target) {
                RuleStatusBadge(isEnabled: rule.isEnabled)
            } else {
                Label("应用失效", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("编辑")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("删除")
        }
        .padding(.vertical, 5)
    }

    private func isTargetResolvable(_ target: ApplicationTarget) -> Bool {
        if FileManager.default.fileExists(atPath: target.applicationURL.path) { return true }
        guard let bundleIdentifier = target.bundleIdentifier else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

private struct ShortcutRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let isEditing: Bool
    private let onSave: (ShortcutRule) throws -> Void
    @State private var key: KeyDescriptor?
    @State private var modifiers: ModifierSet
    @State private var target: ApplicationTarget?
    @State private var consumeOriginalEvent: Bool
    @State private var isEnabled: Bool
    @State private var note: String
    @State private var errorMessage: String?

    init(rule: ShortcutRule?, onSave: @escaping (ShortcutRule) throws -> Void) {
        id = rule?.id ?? UUID()
        isEditing = rule != nil
        self.onSave = onSave
        _key = State(initialValue: rule?.key)
        _modifiers = State(initialValue: rule?.modifiers ?? [])
        _target = State(initialValue: rule?.action.applicationTarget)
        _consumeOriginalEvent = State(initialValue: rule?.consumeOriginalEvent ?? true)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
        _note = State(initialValue: rule?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuleEditorHeader(
                title: isEditing ? "编辑软件快捷键" : "添加软件快捷键",
                subtitle: "使用全局组合键启动或切换到指定应用。",
                systemImage: "command",
                color: .purple
            )
            if let errorMessage { ErrorBanner(message: errorMessage) }
            if let shortcutWarning {
                ErrorBanner(message: shortcutWarning)
            }
            RuleEditorCard {
                RuleEditorRow("快捷键") {
                    HotkeyRecorderView(key: $key, modifiers: $modifiers)
                }
                RuleEditorDivider()
                RuleEditorRow("目标应用") {
                    HStack(spacing: 8) {
                        if let target {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: target.applicationURL.path))
                                .resizable().frame(width: 24, height: 24)
                            Text(target.displayName).lineLimit(1)
                        } else {
                            Text("尚未选择").foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button("选择应用…") { target = ApplicationResolver.chooseApplication() }
                            .fixedSize()
                    }
                }
                RuleEditorDivider()
                RuleEditorRow("按键处理") {
                    Toggle("触发后不传给当前应用", isOn: $consumeOriginalEvent)
                        .toggleStyle(.checkbox)
                }
                RuleEditorDivider()
                RuleEditorRow("备注") {
                    TextField("可选，例如：打开浏览器", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                RuleEditorDivider()
                RuleEditorRow("状态") {
                    Toggle("启用此规则", isOn: $isEnabled)
                        .toggleStyle(.checkbox)
                }
            }
            Text("快捷键可能与 macOS 或其他应用的现有快捷键冲突；KeyPilot 只检查自身规则之间的重复。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(key == nil || modifiers.isEmpty || target == nil)
            }
        }
        .padding(24)
        .frame(width: 590)
    }

    private func save() {
        guard let key, let target else { return }
        do {
            try onSave(ShortcutRule(
                id: id,
                key: key,
                modifiers: modifiers,
                action: .launchApplication(target),
                consumeOriginalEvent: consumeOriginalEvent,
                isEnabled: isEnabled,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var shortcutWarning: String? {
        guard let key else { return nil }
        if modifiers == [.command], key.keyCode == 12 {
            return "⌘Q 是 macOS 的“退出当前应用”快捷键。KeyPilot 可以拦截它，但建议改用 ⌘⌥Q，避免权限或引擎暂时不可用时误退出当前软件。"
        }
        return nil
    }
}
