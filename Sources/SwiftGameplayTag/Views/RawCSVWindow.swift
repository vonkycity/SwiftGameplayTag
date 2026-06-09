import SwiftUI

struct RawCSVWindow: View {
    @Environment(TagStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("原始文件预览").font(.headline)
                    Text(currentFormatLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.csvText.count) 字符")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(12)
            Divider()
            ScrollView([.vertical, .horizontal]) {
                Text(store.csvText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            Divider()
            HStack {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(store.csvText, forType: .string)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
    }

    private var currentFormatLabel: String {
        if let url = store.currentURL {
            return "\(url.lastPathComponent) · 格式:\(store.currentFormat.displayName)"
        }
        return "格式:\(store.currentFormat.displayName)"
    }
}
