import SwiftUI

/// 加根 tag 的弹窗。带合法性检查,名称里不能含 `.` 或空白。
struct AddRootSheet: View {
    @Environment(TagStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建根 Tag").font(.headline)
            Text("输入根 Tag 的名称（不要含 `.` 或空格）。")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("RootName", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("创建") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        let n = trimmed
        guard !n.isEmpty else { return }
        if n.contains(".") || n.contains(where: { $0.isWhitespace }) {
            error = "名称不能含 `.` 或空格"
            return
        }
        store.addRoot(name: n)
        dismiss()
    }
}
