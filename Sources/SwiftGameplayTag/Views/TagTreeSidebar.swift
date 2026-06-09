import SwiftUI

struct TagTreeSidebar: View {
    @Environment(TagStore.self) private var store
    @State private var renaming: RenameState?
    @State private var expandedNodeIDs = Set<UUID>()
    @State private var dropTargetID: UUID?
    @State private var rootDropTargeted = false
    @State private var addChildParentID: UUID?
    /// 抑制加载阶段 Table 同步选择时触开展开。
    @State private var suppressSelectionReveal = true

    private struct RenameState: Equatable {
        let id: GameplayTagNode.ID
        var text: String
    }

    private struct VisibleNode: Identifiable {
        let node: GameplayTagNode
        let depth: Int
        let devComment: String
        let isLeaf: Bool
        let childCount: Int
        var id: UUID { node.id }
        var rowKey: String { "\(node.id.uuidString)-\(isLeaf)-\(childCount)" }
    }

    private var searchVisible: Set<UUID>? {
        store.searchVisibleNodeIDs()
    }

    private var visibleNodes: [VisibleNode] {
        let _ = store.contentRevision
        var out: [VisibleNode] = []
        func walk(_ list: [GameplayTagNode], depth: Int) {
            for node in list {
                if let visible = searchVisible, !visible.contains(node.id) {
                    continue
                }
                out.append(VisibleNode(
                    node: node,
                    depth: depth,
                    devComment: node.tag.devComment.trimmingCharacters(in: .whitespacesAndNewlines),
                    isLeaf: node.isLeaf,
                    childCount: node.children.count
                ))
                if shouldDescend(into: node) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(store.roots, depth: 0)
        return out
    }

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            rootDropRow
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            ScrollViewReader { proxy in
                List(selection: listSelection) {
                    ForEach(visibleNodes) { item in
                        row(for: item)
                            .tag(item.id)
                            .id(item.rowKey)
                    }
                }
                .listStyle(.sidebar)
                .onAppear {
                    scrollToSelection(proxy: proxy)
                    DispatchQueue.main.async { suppressSelectionReveal = false }
                }
                .onChange(of: store.selectedNodeIDs) { _, newValue in
                    let newID = newValue.first
                    if renaming != nil, newID != renaming?.id {
                        commitActiveRename()
                    }
                    if store.shouldRevealSelectionInTree, !suppressSelectionReveal {
                        revealPathToSelection()
                        store.clearSelectionRevealRequest()
                    }
                    scrollToSelection(proxy: proxy)
                }
                .onChange(of: store.documentGeneration) { _, _ in
                    expandedNodeIDs.removeAll()
                    suppressSelectionReveal = true
                    scrollToSelection(proxy: proxy)
                    DispatchQueue.main.async { suppressSelectionReveal = false }
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = ids.first, let node = store.findNode(id: id) {
                        Button("添加子 Tag") { addChildParentID = node.id }
                        Button("重命名…") { beginRename(node) }
                        Divider()
                        Button("删除", role: .destructive) { store.delete([node.id]) }
                    }
                } primaryAction: { ids in
                    guard let id = ids.first, let node = store.findNode(id: id) else { return }
                    beginRename(node)
                }
                .onDeleteCommand {
                    if let id = store.selectedNodeID {
                        store.delete([id])
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: store.duplicateIDs.isEmpty && store.validationIssues.isEmpty
                      ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(store.duplicateIDs.isEmpty && store.validationIssues.isEmpty
                                     ? .green : .orange)
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .sheet(isPresented: Binding(
            get: { addChildParentID != nil },
            set: { if !$0 { addChildParentID = nil } }
        )) {
            if let parentID = addChildParentID {
                AddChildSheet(parentID: parentID)
                    .environment(store)
                    .frame(minWidth: 400, minHeight: 200)
            }
        }
    }

    @ViewBuilder
    private var rootDropRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.to.line")
                .foregroundStyle(.secondary)
            Text("拖到此处移至根级别 · 从 ≡ 手柄拖动")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(rootDropTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .dropDestination(for: TagDragPayload.self) { items, _ in
            guard let payload = items.first else { return false }
            let ok = store.applyDropToRoot(draggedID: payload.id)
            if ok { dropTargetID = nil }
            return ok
        } isTargeted: { rootDropTargeted = $0 }
    }

    @ViewBuilder
    private func row(for item: VisibleNode) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: CGFloat(item.depth) * 14)

            if item.isLeaf {
                Color.clear.frame(width: 14, height: 1)
            } else {
                Button {
                    toggleExpanded(item.node.id)
                } label: {
                    Image(systemName: expandedNodeIDs.contains(item.node.id) ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.borderless)
            }

            if renaming?.id == item.node.id {
                TreeRenameField(text: renameBinding(for: item.node),
                                onCommit: commitActiveRename,
                                onCancel: { renaming = nil })
            } else {
                TreeNodeLabel(node: item.node, devComment: item.devComment, isLeaf: item.isLeaf)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TagDragHandle(nodeID: item.node.id)
        }
        .padding(.vertical, item.devComment.isEmpty ? 1 : 3)
        .tagDropSurface(
            highlighted: dropTargetID == item.node.id,
            onTargetChange: { targeted in
                dropTargetID = targeted ? item.node.id : (dropTargetID == item.node.id ? nil : dropTargetID)
            },
            onDrop: { payload, modifiers in
                let ok = store.applyDrop(
                    draggedID: payload.id,
                    onto: item.node,
                    action: tagDropAction(for: item.node, modifiers: modifiers)
                )
                if ok {
                    revealPathTo(nodeID: payload.id)
                    expandedNodeIDs.insert(item.node.id)
                    dropTargetID = nil
                }
                return ok
            }
        )
    }

    private var listSelection: Binding<UUID?> {
        Binding(
            get: { store.selectedNodeIDs.first },
            set: { id in
                store.selectNode(id)
                if let id { revealPathTo(nodeID: id) }
            }
        )
    }

    private var footerText: String {
        let count = store.flatTags.count
        let shown = searchVisible != nil ? visibleNodes.count : count
        let dup = store.duplicateIDs.count
        let bad = store.validationIssues.count
        let countText = searchVisible != nil ? "\(shown)/\(count) 个 Tag" : "\(count) 个 Tag"
        if dup == 0 && bad == 0 { return countText }
        return "\(countText) · 重复:\(dup) · 校验失败:\(bad)"
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedNodeIDs.contains(id) {
            expandedNodeIDs.remove(id)
        } else {
            expandedNodeIDs.insert(id)
        }
    }

    private func shouldDescend(into node: GameplayTagNode) -> Bool {
        guard !node.isLeaf else { return false }
        if expandedNodeIDs.contains(node.id) { return true }
        guard let visible = searchVisible else { return false }
        return node.children.contains { hasVisibleDescendant($0, visible: visible) }
    }

    private func hasVisibleDescendant(_ node: GameplayTagNode, visible: Set<UUID>) -> Bool {
        if visible.contains(node.id) { return true }
        return node.children.contains { hasVisibleDescendant($0, visible: visible) }
    }

    private func revealPathToSelection() {
        revealPathTo(nodeID: store.selectedNodeID)
    }

    private func revealPathTo(nodeID: UUID?) {
        guard let nodeID, store.findNode(id: nodeID) != nil else { return }
        var parent = store.findNode(id: nodeID)?.parent
        while let p = parent {
            expandedNodeIDs.insert(p.id)
            parent = p.parent
        }
    }

    private func scrollToSelection(proxy: ScrollViewProxy) {
        guard let id = store.selectedNodeID else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func beginRename(_ node: GameplayTagNode) {
        if renaming != nil, renaming?.id != node.id {
            commitActiveRename()
        }
        store.selectNode(node.id)
        renaming = RenameState(id: node.id, text: node.displayName)
    }

    private func commitActiveRename() {
        guard let r = renaming,
              let node = store.findNode(id: r.id) else {
            renaming = nil
            return
        }
        let trimmed = r.text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != node.displayName {
            store.rename(id: r.id, to: trimmed)
        }
        renaming = nil
    }

    private func renameBinding(for node: GameplayTagNode) -> Binding<String> {
        Binding(
            get: {
                if let r = renaming, r.id == node.id { return r.text }
                return node.displayName
            },
            set: { newValue in
                if var r = renaming, r.id == node.id {
                    r.text = newValue
                    renaming = r
                } else {
                    renaming = RenameState(id: node.id, text: newValue)
                }
            }
        )
    }
}

private struct TreeNodeLabel: View {
    let node: GameplayTagNode
    let devComment: String
    let isLeaf: Bool

    var body: some View {
        HStack(alignment: devComment.isEmpty ? .center : .firstTextBaseline, spacing: 6) {
            Image(systemName: isLeaf ? "tag" : "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)

            if devComment.isEmpty {
                Text(node.displayName)
                    .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.displayName)
                        .lineLimit(1)

                    Text(devComment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .help(devComment.isEmpty ? node.tag.name : "\(node.tag.name)\n\(devComment)")
    }
}

private struct TreeRenameField: View {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onSubmit(onCommit)
            .onExitCommand(perform: onCancel)
            .onChange(of: isFocused) { _, focused in
                if !focused { onCommit() }
            }
            .onAppear {
                DispatchQueue.main.async { isFocused = true }
            }
    }
}
