import SwiftUI

struct ToolbarItems: ToolbarContent {
    @Environment(TagStore.self) private var store
    @Environment(FileCommands.self) private var fileCommands
    @Binding var showRaw: Bool
    @Binding var showAddRoot: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                fileCommands.open(using: store)
            } label: {
                Label("打开", systemImage: "doc.text")
            }
            .help("打开 CSV / INI (⌘O)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                fileCommands.save(using: store)
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            .help("保存 (\(store.currentFormat.fileExtension.uppercased()) · ⌘S)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                fileCommands.saveAs()
            } label: {
                Label("另存为", systemImage: "square.and.arrow.down.on.square")
            }
            .help("另存为 (⇧⌘S)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.refreshCSVText()
                showRaw = true
            } label: {
                Label("原始文件", systemImage: "doc.plaintext")
            }
            .help("查看磁盘原文或当前格式的导出预览")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddRoot = true
            } label: {
                Label("新建根 Tag", systemImage: "plus.circle")
            }
            .help("新建根 Tag (⇧⌘N)")
        }
    }
}
