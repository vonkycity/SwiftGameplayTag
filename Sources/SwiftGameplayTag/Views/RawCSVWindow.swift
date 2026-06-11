import SwiftUI

struct RawCSVWindow: View {
    @Environment(TagStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("原始文件预览").font(.headline)
                    Text(previewSubtitle)
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
        .onAppear { store.refreshCSVText() }
        .onChange(of: store.exportRevision) { _, _ in
            store.refreshCSVText()
        }
        .onChange(of: store.isDirty) { _, _ in
            store.refreshCSVText()
        }
        .onChange(of: store.currentFormat) { _, _ in
            store.refreshCSVText()
        }
    }

    private var previewSubtitle: String {
        let format = store.currentFormat.displayName
        if store.rawPreviewShowsLoadedText, let url = store.currentURL {
            return "\(url.lastPathComponent) · 磁盘原文 · \(format)"
        }
        if store.rawPreviewShowsLoadedText {
            return "内置示例 sample.csv · \(format)"
        }
        if store.isDirty {
            return "导出预览 · \(format) · 已修改"
        }
        if store.currentURL != nil {
            return "导出预览 · \(format)"
        }
        return "导出预览 · \(format)"
    }
}
