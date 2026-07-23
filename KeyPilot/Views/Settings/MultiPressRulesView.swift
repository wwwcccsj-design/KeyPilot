import AppKit
import SwiftUI

struct MultiPressRulesView: View {
    @EnvironmentObject private var appState: AppState
    let creationRequestID: UUID?
    let onCreationRequestHandled: () -> Void
    let editingRequestRuleID: UUID?
    let onEditingRequestHandled: () -> Void
    @State private var editorPresentation: RuleEditorPresentation<MultiPressRule>?

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
                    Text("连按动作").font(.title2.bold())
                    Text("快速连按一个按键，打开应用或输出另一个按键。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                } label: {
                    Label("添加连按动作", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.configuration.multiPressRules.isEmpty {
                EmptyStateView(
                    systemImage: "hand.tap",
                    title: "还没有连按动作",
                    message: "例如快速按两次 Q 打开微信，或快速按两次 A 输出 B。",
                    buttonTitle: "添加连按动作"
                ) {
                    editorPresentation = RuleEditorPresentation(rule: nil)
                }
            } else {
                List {
                    ForEach(appState.configuration.multiPressRules) { rule in
                        MultiPressRuleRow(rule: rule) {
                            appState.setMultiPressEnabled(id: rule.id, enabled: $0)
                        } onEdit: {
                            editorPresentation = RuleEditorPresentation(rule: rule)
                        } onDelete: {
                            appState.removeMultiPress(id: rule.id)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $editorPresentation) { presentation in
            MultiPressRuleEditor(rule: presentation.rule) { rule in
                try appState.upsertMultiPress(rule)
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
              let rule = appState.configuration.multiPressRules.first(where: { $0.id == ruleID }) else { return }
        DispatchQueue.main.async {
            editorPresentation = RuleEditorPresentation(rule: rule)
            onEditingRequestHandled()
        }
    }
}

private struct MultiPressRuleRow: View {
    let rule: MultiPressRule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: onToggle)).labelsHidden()
            Text(rule.displayTrigger)
                .font(.system(.body, design: .monospaced).bold())
                .frame(minWidth: 72)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            actionLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("≤ \(rule.maxIntervalMilliseconds) ms")
                .font(.caption).foregroundStyle(.secondary)
            RuleStatusBadge(isEnabled: rule.isEnabled)
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("编辑")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("删除")
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var actionLabel: some View {
        switch rule.action {
        case let .launchApplication(target):
            HStack(spacing: 7) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: target.applicationURL.path))
                    .resizable().frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("打开 \(target.displayName)").fontWeight(.medium)
                    Text(rule.note ?? target.applicationURL.path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        case let .emitKey(target):
            VStack(alignment: .leading, spacing: 1) {
                Text("输出 \(target.displayName)").fontWeight(.medium)
                if let note = rule.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

private enum MultiPressActionKind: String, CaseIterable {
    case launchApplication
    case emitKey

    var displayName: String {
        switch self {
        case .launchApplication: return "打开应用"
        case .emitKey: return "输出按键"
        }
    }
}

private struct MultiPressRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    private let id: UUID
    private let isEditing: Bool
    private let onSave: (MultiPressRule) throws -> Void
    @State private var source: KeyDescriptor?
    @State private var pressCount: Int
    @State private var maxIntervalMilliseconds: Int
    @State private var actionKind: MultiPressActionKind
    @State private var applicationTarget: ApplicationTarget?
    @State private var outputKey: KeyDescriptor?
    @State private var isEnabled: Bool
    @State private var note: String
    @State private var errorMessage: String?

    init(rule: MultiPressRule?, onSave: @escaping (MultiPressRule) throws -> Void) {
        id = rule?.id ?? UUID()
        isEditing = rule != nil
        self.onSave = onSave
        _source = State(initialValue: rule?.source)
        _pressCount = State(initialValue: rule?.pressCount ?? 2)
        _maxIntervalMilliseconds = State(initialValue: rule?.maxIntervalMilliseconds ?? 350)
        _actionKind = State(initialValue: rule?.action.outputKey == nil ? .launchApplication : .emitKey)
        _applicationTarget = State(initialValue: rule?.action.applicationTarget)
        _outputKey = State(initialValue: rule?.action.outputKey)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
        _note = State(initialValue: rule?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuleEditorHeader(
                title: isEditing ? "编辑连按动作" : "添加连按动作",
                subtitle: "连续按下同一个键后执行指定动作。",
                systemImage: "hand.tap",
                color: .orange
            )
            if let errorMessage { ErrorBanner(message: errorMessage) }
            RuleEditorCard {
                VStack(spacing: 0) {
                    RuleEditorRow("触发按键") {
                        KeyRecorderView(selection: $source)
                    }
                    RuleEditorDivider()
                    RuleEditorRow("连按次数") {
                        Picker("连按次数", selection: $pressCount) {
                            ForEach(Array(MultiPressRule.allowedPressCounts), id: \.self) { count in
                                Text("\(count) 次").tag(count)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                    RuleEditorDivider()
                    RuleEditorRow("最大间隔") {
                        Stepper(
                            "\(maxIntervalMilliseconds) 毫秒",
                            value: $maxIntervalMilliseconds,
                            in: MultiPressRule.allowedIntervalMilliseconds,
                            step: 50
                        )
                        .fixedSize()
                    }
                    RuleEditorDivider()
                    RuleEditorRow("触发动作") {
                        Picker("触发动作", selection: $actionKind) {
                            ForEach(MultiPressActionKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                }
                VStack(spacing: 0) {
                    RuleEditorDivider()
                    if actionKind == .launchApplication {
                        RuleEditorRow("目标应用") {
                            HStack(spacing: 8) {
                                if let applicationTarget {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: applicationTarget.applicationURL.path))
                                        .resizable().frame(width: 24, height: 24)
                                    Text(applicationTarget.displayName).lineLimit(1)
                                } else {
                                    Text("尚未选择").foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Button("选择应用…") {
                                    applicationTarget = ApplicationResolver.chooseApplication()
                                }
                                .fixedSize()
                            }
                        }
                    } else {
                        RuleEditorRow("输出按键") {
                            KeyRecorderView(selection: $outputKey)
                        }
                    }
                    RuleEditorDivider()
                    RuleEditorRow("备注") {
                        TextField("可选，例如：连按空格打开微信", text: $note)
                            .textFieldStyle(.roundedBorder)
                    }
                    RuleEditorDivider()
                    RuleEditorRow("状态") {
                        Toggle("启用此规则", isOn: $isEnabled)
                            .toggleStyle(.checkbox)
                    }
                }
            }
            Text("未在设定时间内完成连按时，KeyPilot 会回放原按键；因此这个键的普通单击最多会延迟上述时间。带修饰键输入和长按不触发连按动作。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 580)
    }

    private var canSave: Bool {
        guard source != nil else { return false }
        switch actionKind {
        case .launchApplication: return applicationTarget != nil
        case .emitKey: return outputKey != nil
        }
    }

    private func save() {
        guard let source else { return }
        let action: MultiPressAction
        switch actionKind {
        case .launchApplication:
            guard let applicationTarget else { return }
            action = .launchApplication(applicationTarget)
        case .emitKey:
            guard let outputKey else { return }
            action = .emitKey(outputKey)
        }

        do {
            try onSave(MultiPressRule(
                id: id,
                source: source,
                pressCount: pressCount,
                maxIntervalMilliseconds: maxIntervalMilliseconds,
                action: action,
                isEnabled: isEnabled,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
