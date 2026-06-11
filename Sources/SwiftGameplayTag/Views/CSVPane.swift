import SwiftUI

struct CSVPane: View {
    @Environment(TagStore.self) private var store
    @State private var sortOrder: [KeyPathComparator<GameplayTag>] = [
        .init(\.name, order: .forward)
    ]
    /// Table 内部选择状态。macOS Table 在外部改 store 时不会自己刷新高亮,需要本地镜像。
    @State private var tableSelection: Set<UUID> = []
    /// 避免 Table → store 回写后再把选择同步/滚动覆盖掉。
    @State private var selectionDrivenByTable = false

    private var sortedRows: [GameplayTag] {
        store.filteredFlatTags.sorted(using: sortOrder)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Table(sortedRows, selection: $tableSelection, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { tag in
                    let selected = tableSelection.contains(tag.id)
                    TableTextCell(
                        value: tag.name,
                        monospaced: true,
                        emphasisColor: selected ? nil : nameColor(for: tag)
                    ) { newValue in
                        commitName(id: tag.id, text: newValue)
                    }
                    .id(tag.id)
                }
                .width(min: 200, ideal: 280)

                TableColumn("DevComment", value: \.devComment) { tag in
                    TableTextCell(value: tag.devComment) { newValue in
                        store.updateMetadata(id: tag.id, devComment: newValue)
                    }
                }
                .width(min: 120, ideal: 200)
            }
            .id(store.documentGeneration)
            .contextMenu(forSelectionType: GameplayTag.ID.self) { ids in
                Button("删除", role: .destructive) { store.delete(ids) }
            }
            .onAppear {
                syncTableSelectionFromStore()
                scrollToSelection(store.selectedNodeID, proxy: proxy)
            }
            .onChange(of: store.selectedNodeIDs) { _, newValue in
                guard !selectionDrivenByTable else { return }
                pushStoreSelectionToTable(newValue)
                scrollToSelection(newValue.first, proxy: proxy)
            }
            .onChange(of: store.documentGeneration) { _, _ in
                syncTableSelectionFromStore()
                scrollToSelection(store.selectedNodeID, proxy: proxy)
            }
            .onChange(of: tableSelection) { _, newValue in
                selectionDrivenByTable = true
                pushTableSelectionToStore(newValue)
                DispatchQueue.main.async {
                    selectionDrivenByTable = false
                }
            }
        }
    }

    private func pushStoreSelectionToTable(_ ids: Set<UUID>) {
        guard tableSelection != ids else { return }
        tableSelection = ids
    }

    private func syncTableSelectionFromStore() {
        tableSelection = store.selectedNodeIDs
    }

    private func pushTableSelectionToStore(_ ids: Set<UUID>) {
        guard ids != store.selectedNodeIDs else { return }

        if ids.count == 1 {
            store.selectNodeFromTable(ids.first)
        } else if ids.isEmpty {
            store.selectNode(nil)
        } else {
            store.selectedNodeIDs = ids
        }
    }

    private func scrollToSelection(_ id: UUID?, proxy: ScrollViewProxy) {
        guard let id else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func nameColor(for tag: GameplayTag) -> Color {
        if store.duplicateIDs.contains(tag.id) { return .red }
        if store.validationIssues[tag.id] != nil { return .orange }
        return .primary
    }

    private func commitName(id: UUID, text: String) {
        guard let node = store.findNode(id: id) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != node.tag.name else { return }

        let newLeaf: String
        if let parent = node.parent {
            let prefix = parent.tag.name + "."
            if trimmed.hasPrefix(prefix) {
                newLeaf = String(trimmed.dropFirst(prefix.count))
                guard !newLeaf.isEmpty, !newLeaf.contains(".") else { return }
            } else if !trimmed.contains(".") {
                newLeaf = trimmed
            } else {
                return
            }
        } else {
            guard !trimmed.contains(".") else { return }
            newLeaf = trimmed
        }
        store.rename(id: id, to: newLeaf)
    }
}

private struct TableTextCell: View {
    let value: String
    var monospaced = false
    var emphasisColor: Color?
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(
        value: String,
        monospaced: Bool = false,
        emphasisColor: Color? = nil,
        onCommit: @escaping (String) -> Void
    ) {
        self.value = value
        self.monospaced = monospaced
        self.emphasisColor = emphasisColor
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    private var font: Font {
        monospaced ? .system(.body, design: .monospaced) : .body
    }

    var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(font)
            .modifier(OptionalForegroundStyle(color: emphasisColor))
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                if !focused { commitIfChanged() }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused { draft = newValue }
            }
            .onAppear { draft = value }
    }

    private func commitIfChanged() {
        guard draft != value else { return }
        onCommit(draft)
    }
}

/// 选中行不覆盖前景色,交给 Table 原生绘制;未选中行可显示校验色。
private struct OptionalForegroundStyle: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content.foregroundStyle(color)
        } else {
            content
        }
    }
}
