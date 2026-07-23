import SwiftUI

struct RuleStatusBadge: View {
    let isEnabled: Bool

    var body: some View {
        Text(isEnabled ? "已启用" : "已停用")
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(isEnabled ? .green : .secondary)
            .background((isEnabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
    }
}
