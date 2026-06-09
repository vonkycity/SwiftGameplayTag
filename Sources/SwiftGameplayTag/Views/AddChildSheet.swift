import SwiftUI

/// 在指定父节点下添加子 Tag。
struct AddChildSheet: View {
    let parentID: UUID

    @Environment(TagStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var error: String?

    private var parent: GameplayTagNode? {
        store.findNode(id: parentID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加子 Tag").font(.headline)

            if let parent {
                Text("父节点：\(parent.tag.name)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            Text("输入子 Tag 的名称（仅最后一段，不要含 `.` 或空格）。")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("ChildName", text: $name)
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
        guard let newID = store.addChild(under: parentID, name: n) else {
            error = "无法添加子 Tag"
            return
        }
        store.selectNode(newID)
        dismiss()
    }
}
