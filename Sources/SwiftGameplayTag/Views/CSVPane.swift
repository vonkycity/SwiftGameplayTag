import SwiftUI

struct CSVPane: View {
    @Environment(TagStore.self) private var store
    @State private var sortOrder: [KeyPathComparator<GameplayTag>] = [
        .init(\.name, order: .forward)
    ]
    /// Table 内部选择状态。macOS Table 在外部改 store 时不会自己刷新高亮,需要本地镜像。
    @State private var tableSelection: Set<UUID> = []

    private var sortedRows: [GameplayTag] {
        store.filteredFlatTags.sorted(using: sortOrder)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Table(sortedRows, selection: $tableSelection, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { tag in
                    TableTextCell(value: tag.name, monospaced: true) { newValue in
                        commitName(id: tag.id, text: newValue)
                    }
                    .foregroundStyle(nameColor(for: tag))
                    .id(tag.id)
                }
                .width(min: 200, ideal: 280)

                TableColumn("DevComment", value: \.devComment) { tag in
                    TableTextCell(value: tag.devComment) { newValue in
                        store.updateMetadata(id: tag.id, devComment: newValue)
                    }
                }
                .width(min: 120, ideal: 200)

                TableColumn("Category", value: \.optionalCategory) { tag in
                    TableTextCell(value: tag.category ?? "") { newValue in
                        if newValue.isEmpty {
                            store.updateMetadata(id: tag.id, clearCategory: true)
                        } else {
                            store.updateMetadata(id: tag.id, category: newValue)
                        }
                    }
                }
                .width(min: 80, ideal: 120)

                TableColumn("Hidden") { (tag: GameplayTag) in
                    Toggle("", isOn: hiddenBinding(tag.id))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
                .width(60)
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
                pushStoreSelectionToTable(newValue)
                scrollToSelection(newValue.first, proxy: proxy)
            }
            .onChange(of: store.documentGeneration) { _, _ in
                syncTableSelectionFromStore()
                scrollToSelection(store.selectedNodeID, proxy: proxy)
            }
            .onChange(of: tableSelection) { _, newValue in
                pushTableSelectionToStore(newValue)
            }
        }
    }

    /// 左侧树 / 外部改 store → 强制同步到 Table 本地选择。
    private func pushStoreSelectionToTable(_ ids: Set<UUID>) {
        guard tableSelection != ids else { return }
        tableSelection = ids
    }

    private func syncTableSelectionFromStore() {
        tableSelection = store.selectedNodeIDs
    }

    /// Table 用户点击 → 写回 store。忽略 Table 误报的空白选择(行尚未渲染时常见)。
    private func pushTableSelectionToStore(_ ids: Set<UUID>) {
        guard ids != store.selectedNodeIDs else { return }

        if ids.isEmpty,
           let current = store.selectedNodeID,
           sortedRows.contains(where: { $0.id == current }) {
            DispatchQueue.main.async {
                tableSelection = store.selectedNodeIDs
            }
            return
        }

        store.selectedNodeIDs = ids
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

    private func hiddenBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { store.findNode(id: id)?.tag.isHidden ?? false },
            set: { store.updateMetadata(id: id, isHidden: $0) }
        )
    }
}

private struct TableTextCell: View {
    let value: String
    var monospaced = false
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(value: String, monospaced: Bool = false, onCommit: @escaping (String) -> Void) {
        self.value = value
        self.monospaced = monospaced
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            .foregroundStyle(Color(nsColor: .textColor))
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

private extension GameplayTag {
    var optionalCategory: String { category ?? "" }
}
