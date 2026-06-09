import SwiftUI
import UniformTypeIdentifiers

/// 另存为的格式选择弹窗。选完格式后弹出 NSSavePanel。
struct SaveAsSheet: View {
    @Environment(TagStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var format: TagFileFormat = .dataTableCSV
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("另存为…").font(.headline)
            Text("选择导出格式,然后选择保存位置。")
                .foregroundStyle(.secondary)
                .font(.caption)

            Picker("格式", selection: $format) {
                ForEach(TagFileFormat.allCases, id: \.self) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .pickerStyle(.radioGroup)

            GroupBox("预览前几行") {
                ScrollView {
                    Text(preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 140)
                .background(Color(nsColor: .textBackgroundColor))
            }

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存…") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private var preview: String {
        let text = store.exportText(format: format)
        let lines = text.split(separator: "\n").prefix(8)
        return lines.joined(separator: "\n")
    }

    private func save() {
        NSSavePanel.run(format: format) { url in
            guard let url else { return }
            do {
                try store.save(to: url, format: format)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

extension NSSavePanel {
    /// macOS NSSavePanel 包装,根据 TagFileFormat 设定 allowedContentTypes / 扩展名。
    static func run(format: TagFileFormat, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        switch format {
        case .dataTableCSV:
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = defaultName(format: format, ext: "csv")
        case .ini:
            panel.allowedContentTypes = [UTType("public.ini") ?? .data, .plainText]
            panel.nameFieldStringValue = defaultName(format: format, ext: "ini")
        }
        panel.canCreateDirectories = true
        panel.title = "保存为 \(format.displayName)"
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    private static func defaultName(format: TagFileFormat, ext: String) -> String {
        switch format {
        case .dataTableCSV: return "GameplayTagTable.\(ext)"
        case .ini:          return "DefaultGameplayTags.\(ext)"
        }
    }
}
