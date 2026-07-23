import SwiftUI

struct KeyRecorderView: View {
    @Binding var selection: KeyDescriptor?
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording.toggle()
            } label: {
                HStack {
                    Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                    Text(isRecording ? "请按一个按键…" : (selection?.displayName ?? "录入按键"))
                }
                .frame(minWidth: 115)
            }
            if isRecording {
                Button("设为 Escape") {
                    selection = KeyDescriptor(keyCode: 53)
                    isRecording = false
                }
                Button("取消") { isRecording = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .background {
            KeyEventMonitor(isActive: isRecording) { event in
                let keyCode = UInt16(event.keyCode)
                if keyCode == 53 {
                    isRecording = false
                } else if !KeyCodeNames.modifierKeyCodes.contains(keyCode) {
                    selection = KeyDescriptor(keyCode: keyCode)
                    isRecording = false
                }
            }
        }
        .accessibilityLabel("按键录入")
    }
}
