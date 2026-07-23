import SwiftUI

struct RemapRulesView: View {
    @EnvironmentObject private var appState: AppState
    let creationRequestID: UUID?
    let onCreationRequestHandled: () -> Void
    let editingRequestRuleID: UUID?
    let onEditingRequestHandled: () -> Void
    @State private var editorPresentation: RuleEditorPresentation<RemapRule>?

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
                    Text("键位映射").font(.title2.bold())
                    Text("按虚拟键码替换按键，同时处理按下与松开事件。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                } label: {
                    Label("添加规则", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.configuration.remapRules.isEmpty {
                EmptyStateView(
                    systemImage: "keyboard",
                    title: "还没有键位规则",
                    message: "添加一条规则，将不顺手的按键换到更方便的位置。",
                    buttonTitle: "添加键位映射"
                ) {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                }
            } else {
                List {
                    ForEach(appState.configuration.remapRules) { rule in
                        RemapRuleRow(rule: rule) {
                            appState.setRemapEnabled(id: rule.id, enabled: $0)
                        } onEdit: {
                            editorPresentation = RuleEditorPresentation(rule: rule)
                        } onDelete: {
                            appState.removeRemap(id: rule.id)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $editorPresentation) { presentation in
            RemapRuleEditor(rule: presentation.rule) { rule in
                try appState.upsertRemap(rule)
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
              let rule = appState.configuration.remapRules.first(where: { $0.id == ruleID }) else { return }
        DispatchQueue.main.async {
            editorPresentation = RuleEditorPresentation(rule: rule)
            onEditingRequestHandled()
        }
    }
}

private struct RemapRuleRow: View {
    let rule: RemapRule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: onToggle))
                .labelsHidden()
            Text(rule.source.displayName)
                .font(.system(.body, design: .monospaced).bold())
                .frame(minWidth: 64)
            Text(rule.mode.symbol).foregroundStyle(.secondary)
            Text(rule.target.displayName)
                .font(.system(.body, design: .monospaced).bold())
                .frame(minWidth: 64)
            RuleStatusBadge(isEnabled: rule.isEnabled)
            Text(rule.note.flatMap { $0.isEmpty ? nil : $0 } ?? "无备注")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("编辑")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("删除")
        }
        .padding(.vertical, 5)
    }
}

private struct RemapRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let isEditing: Bool
    private let onSave: (RemapRule) throws -> Void
    @State private var source: KeyDescriptor?
    @State private var target: KeyDescriptor?
    @State private var mode: RemapMode
    @State private var isEnabled: Bool
    @State private var note: String
    @State private var errorMessage: String?

    init(rule: RemapRule?, onSave: @escaping (RemapRule) throws -> Void) {
        id = rule?.id ?? UUID()
        isEditing = rule != nil
        self.onSave = onSave
        _source = State(initialValue: rule?.source)
        _target = State(initialValue: rule?.target)
        _mode = State(initialValue: rule?.mode ?? .oneWay)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
        _note = State(initialValue: rule?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuleEditorHeader(
                title: isEditing ? "编辑键位映射" : "添加键位映射",
                subtitle: "将一个物理按键替换或交换为另一个按键。",
                systemImage: "arrow.left.arrow.right",
                color: .blue
            )
            if let errorMessage { ErrorBanner(message: errorMessage) }
            RuleEditorCard {
                RuleEditorRow("原按键") {
                    KeyRecorderView(selection: $source)
                }
                RuleEditorDivider()
                RuleEditorRow("目标按键") {
                    KeyRecorderView(selection: $target)
                }
                RuleEditorDivider()
                RuleEditorRow("映射模式") {
                    Picker("映射模式", selection: $mode) {
                        ForEach(RemapMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                RuleEditorDivider()
                RuleEditorRow("备注") {
                    TextField("可选，例如：右括号替换为 B", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                RuleEditorDivider()
                RuleEditorRow("状态") {
                    Toggle("启用此规则", isOn: $isEnabled)
                        .toggleStyle(.checkbox)
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(source == nil || target == nil)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func save() {
        guard let source, let target else { return }
        do {
            try onSave(RemapRule(
                id: id,
                source: source,
                target: target,
                mode: mode,
                isEnabled: isEnabled,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
