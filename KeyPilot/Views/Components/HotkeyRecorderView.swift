import SwiftUI

struct HotkeyRecorderView: View {
    @Binding var key: KeyDescriptor?
    @Binding var modifiers: ModifierSet
    @State private var isRecording = false
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button {
                    hint = nil
                    isRecording.toggle()
                } label: {
                    HStack {
                        Image(systemName: "command")
                        Text(isRecording ? "请按组合键…" : displayValue)
                    }
                    .frame(minWidth: 150)
                }
                if isRecording {
                    Button("取消") { isRecording = false }
                        .keyboardShortcut(.cancelAction)
                }
            }
            if let hint {
                Text(hint).font(.caption).foregroundStyle(.orange)
            }
        }
        .background {
            KeyEventMonitor(isActive: isRecording) { event in
                let keyCode = UInt16(event.keyCode)
                if keyCode == 53 {
                    isRecording = false
                    return
                }
                guard !KeyCodeNames.modifierKeyCodes.contains(keyCode) else { return }
                let capturedModifiers = ModifierSet(eventFlags: event.modifierFlags)
                guard !capturedModifiers.isEmpty else {
                    hint = "至少同时按住 ⌘、⌥、⌃ 或 ⇧ 中的一个。"
                    return
                }
                key = KeyDescriptor(keyCode: keyCode)
                modifiers = capturedModifiers
                hint = nil
                isRecording = false
            }
        }
        .accessibilityLabel("软件快捷键录入")
    }

    private var displayValue: String {
        guard let key else { return "录入快捷键" }
        return modifiers.displayString + key.displayName
    }
}
