import Foundation
import SwiftUI
import AppKit

/// 全局状态。负责:
/// - 树的增删改
/// - 撤销/重做
/// - 路径校验、重复检测
/// - CSV 文本同步(只读派发,不接受编辑)
@MainActor
@Observable
final class TagStore {

    // MARK: - 发布状态

    private(set) var roots: [GameplayTagNode] = []
    private(set) var csvText: String = ""
    private(set) var currentURL: URL?
    private(set) var currentFormat: TagFileFormat = .dataTableCSV
    private(set) var validationIssues: [UUID: GameplayTag.ValidationError] = [:]
    private(set) var duplicateIDs: Set<UUID> = []
    private(set) var isDirty: Bool = false
    var searchQuery: String = ""
    var selectedNodeIDs: Set<UUID> = []
    private(set) var documentGeneration = UUID()
    /// 右侧 Table 用户点击后请求左侧树展开到选中项。
    private(set) var shouldRevealSelectionInTree = false
    /// 节点内容变更计数,驱动左侧树在 metadata 编辑后刷新。
    private(set) var contentRevision: Int = 0
    /// 导出内容变更计数;打开预览 / 保存前再生成 csvText。
    private(set) var exportRevision: Int = 0

    /// 当前选中的单个节点(左侧 List 使用)。
    var selectedNodeID: UUID? { selectedNodeIDs.first }

    func selectNode(_ id: UUID?) {
        if let id {
            selectedNodeIDs = [id]
        } else {
            selectedNodeIDs = []
        }
    }

    func selectNodeFromTable(_ id: UUID?) {
        selectNode(id)
        shouldRevealSelectionInTree = id != nil
    }

    func clearSelectionRevealRequest() {
        shouldRevealSelectionInTree = false
    }

    /// 窗口标题(含修改标记)。
    var windowTitle: String {
        isDirty ? "GameplayTag 编辑器 — 已修改" : "GameplayTag 编辑器"
    }

    // MARK: - 撤销/重做

    private enum UndoEntry {
        case tree([GameplayTag])
        case metadata(nodeID: UUID, snapshot: GameplayTag)
    }

    @ObservationIgnored private var undoStack: [UndoEntry] = []
    @ObservationIgnored private var redoStack: [UndoEntry] = []
    @ObservationIgnored private var loadedFileText: String?
    @ObservationIgnored private let maxHistory = 100
    @ObservationIgnored private var searchCacheQuery: String = ""
    @ObservationIgnored private var searchCacheVisible: Set<UUID>?

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - 派生 / 索引

    private(set) var flatTags: [GameplayTag] = []
    @ObservationIgnored private var nodeByID: [UUID: GameplayTagNode] = [:]

    /// 搜索时应显示的节点 id(命中节点 + 全部祖先)。无搜索时返回 nil。
    func searchVisibleNodeIDs() -> Set<UUID>? {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }

        if q == searchCacheQuery, let searchCacheVisible {
            return searchCacheVisible
        }

        var hits: Set<UUID> = []
        GameplayTagNode.forEach(in: roots) { node in
            if matchesSearch(node, query: q) {
                hits.insert(node.id)
            }
        }

        var visible: Set<UUID> = []
        for hitID in hits {
            var current = findNode(id: hitID)
            while let node = current {
                visible.insert(node.id)
                current = node.parent
            }
        }
        searchCacheQuery = q
        searchCacheVisible = visible
        return visible
    }

    /// 右侧 Table 使用的行(搜索时过滤)。
    var filteredFlatTags: [GameplayTag] {
        guard let visible = searchVisibleNodeIDs() else { return flatTags }
        return flatTags.filter { visible.contains($0.id) }
    }

    /// 原始文件预览是否展示已加载文本(未修改)。
    var rawPreviewShowsLoadedText: Bool {
        !isDirty && loadedFileText != nil
    }

    /// 确保 csvText 为最新(打开原始文件预览前调用)。
    func refreshCSVText() {
        if !isDirty, let text = loadedFileText {
            csvText = text
        } else {
            csvText = CSVBridge.export(roots, format: currentFormat)
        }
    }

    // MARK: - 加载 / 导出

    func loadFile(from url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let parsed = CSVBridge.parse(text)
        undoStack.removeAll()
        redoStack.removeAll()
        currentURL = url
        currentFormat = parsed.format
        loadedFileText = text
        isDirty = false
        applyTags(parsed.tags, recordHistory: false)
        csvText = text
        resetSelection(selectFirst: true)
    }

    func loadSample() {
        let text = SampleCSV.content
        let parsed = CSVBridge.parse(text)
        undoStack.removeAll()
        redoStack.removeAll()
        currentURL = nil
        loadedFileText = text
        currentFormat = parsed.format
        isDirty = false
        applyTags(parsed.tags, recordHistory: false)
        csvText = text
        resetSelection(selectFirst: true)
    }

    private func resetSelection(selectFirst: Bool) {
        documentGeneration = UUID()
        if selectFirst {
            selectNode(roots.first?.id)
        } else {
            selectNode(nil)
        }
    }

    func save() throws {
        guard let url = currentURL else { throw saveNeedsURLError() }
        try save(to: url, format: currentFormat)
    }

    func save(to url: URL, format: TagFileFormat) throws {
        let text = CSVBridge.export(roots, format: format)
        try text.write(to: url, atomically: true, encoding: .utf8)
        currentURL = url
        currentFormat = format
        loadedFileText = text
        csvText = text
        isDirty = false
    }

    func exportText(format: TagFileFormat) -> String {
        CSVBridge.export(roots, format: format)
    }

    /// 打开新文件 / 加载示例前,若有未保存修改则弹窗确认。
    func confirmDiscardChangesIfNeeded() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "放弃未保存的修改?"
        alert.informativeText = "当前文档有未保存的修改,继续将丢失这些更改。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "放弃")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func saveNeedsURLError() -> Error {
        NSError(domain: "TagStore", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "请先用 ⌘O 打开一个文件,或选择「另存为」。"])
    }

    // MARK: - 树操作(CRUD)

    @discardableResult
    func addRoot(name: String = "NewRoot") -> GameplayTagNode.ID {
        recordTreeHistory()
        let unique = uniqueName(based: name, parentName: nil)
        let node = GameplayTagNode(tag: GameplayTag(name: unique))
        roots.append(node)
        rebuildDerivedState()
        markDirty()
        return node.id
    }

    @discardableResult
    func addChild(under id: GameplayTagNode.ID, name: String? = nil) -> GameplayTagNode.ID? {
        guard let parent = findNode(id: id) else { return nil }
        recordTreeHistory()
        let baseName = name ?? "NewTag"
        let unique = uniqueName(based: baseName, parentName: parent.tag.name)
        let node = GameplayTagNode(tag: GameplayTag(name: unique), parent: parent)
        parent.children.append(node)
        rebuildDerivedState()
        markDirty()
        return node.id
    }

    func delete(_ ids: Set<GameplayTagNode.ID>) {
        guard !ids.isEmpty else { return }
        recordTreeHistory()
        var toDelete: [GameplayTagNode] = []
        GameplayTagNode.forEach(in: roots) { node in
            if ids.contains(node.id) { toDelete.append(node) }
        }
        guard !toDelete.isEmpty else { return }
        for node in toDelete {
            if let parent = node.parent {
                parent.children.removeAll { $0.id == node.id }
            } else {
                roots.removeAll { $0.id == node.id }
            }
        }
        rebuildDerivedState()
        markDirty()
        if let sel = selectedNodeID, ids.contains(sel) {
            selectNode(nil)
        }
    }

    func rename(id: GameplayTagNode.ID, to newLeafName: String) {
        guard let node = findNode(id: id) else { return }
        let newName = composeName(parent: node.parent?.tag.name, leaf: newLeafName)
        if newName == node.tag.name { return }
        recordTreeHistory()
        let oldName = node.tag.name
        let prefix = oldName + "."
        node.tag.name = newName
        GameplayTagNode.forEach(node) { child in
            if child.tag.name.hasPrefix(prefix) {
                child.tag.name = newName + "." + child.tag.name.dropFirst(prefix.count)
            }
        }
        rebuildDerivedState()
        markDirty()
    }

    func updateMetadata(id: GameplayTagNode.ID, devComment: String) {
        guard let node = findNode(id: id) else { return }
        guard devComment != node.tag.devComment else { return }

        recordMetadataHistory(node: node)
        var updated = node.tag
        updated.devComment = devComment
        node.tag = updated
        if let idx = flatTags.firstIndex(where: { $0.id == id }) {
            flatTags[idx].devComment = devComment
        }
        invalidateSearchCache()
        exportRevision &+= 1
        contentRevision &+= 1
        markDirty()
    }

    /// 将节点移动到新父节点下;`insertBefore` 指定同级插入位置(仅影响顺序,不改变层级语义)。
    func move(id: GameplayTagNode.ID,
              toParent newParentID: GameplayTagNode.ID?,
              insertBefore siblingID: UUID? = nil) {
        guard let node = findNode(id: id) else { return }

        if let np = newParentID {
            if np == id { return }
            if node.contains(id: np) { return }
        }

        let newParentNode: GameplayTagNode? = newParentID.flatMap { findNode(id: $0) }
        let oldParentID = node.parent?.id

        if oldParentID == newParentID,
           siblingID == nil,
           node.parent?.children.last?.id == id,
           newParentID != nil || roots.last?.id == id {
            return
        }

        recordTreeHistory()
        detach(node)

        let insertIndex: Int?
        if let siblingID {
            let siblings = newParentNode?.children ?? roots
            insertIndex = siblings.firstIndex(where: { $0.id == siblingID })
        } else {
            insertIndex = nil
        }

        attach(node, under: newParentNode, at: insertIndex)

        let parentChanged = oldParentID != newParentID
        if parentChanged {
            updatePathPrefix(node)
            makeNameUnique(node)
            fixAllParents()
            rebuildDerivedState()
        } else {
            fixAllParents()
            rebuildDerivedState()
        }
        markDirty()
    }

    /// 在同级中,将 `id` 移动到 `targetID` 之前(不改变父节点)。
    func reorder(id: GameplayTagNode.ID, before targetID: GameplayTagNode.ID) {
        guard let node = findNode(id: id),
              let target = findNode(id: targetID),
              id != targetID else { return }

        let parent = target.parent
        let oldParentID = node.parent?.id

        recordTreeHistory()
        detach(node)

        let siblings = parent?.children ?? roots
        let insertIndex = siblings.firstIndex(where: { $0.id == targetID }) ?? siblings.count
        attach(node, under: parent, at: insertIndex)

        applyAfterReorder(node: node, oldParentID: oldParentID, newParentID: parent?.id)
    }

    /// 在同级中,将 `id` 移动到 `targetID` 之后。
    func reorder(id: GameplayTagNode.ID, after targetID: GameplayTagNode.ID) {
        guard let node = findNode(id: id),
              let target = findNode(id: targetID),
              id != targetID else { return }

        let parent = target.parent
        let oldParentID = node.parent?.id

        recordTreeHistory()
        detach(node)

        let siblings = parent?.children ?? roots
        let insertIndex: Int
        if let targetIndex = siblings.firstIndex(where: { $0.id == targetID }) {
            insertIndex = targetIndex + 1
        } else {
            insertIndex = siblings.count
        }
        attach(node, under: parent, at: insertIndex)

        applyAfterReorder(node: node, oldParentID: oldParentID, newParentID: parent?.id)
    }

    private func applyAfterReorder(node: GameplayTagNode, oldParentID: UUID?, newParentID: UUID?) {
        let parentChanged = oldParentID != newParentID
        if parentChanged {
            updatePathPrefix(node)
            makeNameUnique(node)
            fixAllParents()
            rebuildDerivedState()
        } else {
            fixAllParents()
            rebuildDerivedState()
        }
        markDirty()
    }

    // MARK: - move 辅助

    private func detach(_ node: GameplayTagNode) {
        if let parent = node.parent {
            parent.children.removeAll { $0.id == node.id }
        } else {
            roots.removeAll { $0.id == node.id }
        }
        node.parent = nil
    }

    private func attach(_ node: GameplayTagNode, under parent: GameplayTagNode?, at index: Int? = nil) {
        if let parent {
            let clamped = min(max(index ?? parent.children.count, 0), parent.children.count)
            parent.children.insert(node, at: clamped)
            node.parent = parent
        } else {
            let clamped = min(max(index ?? roots.count, 0), roots.count)
            roots.insert(node, at: clamped)
            node.parent = nil
        }
    }

    private func updatePathPrefix(_ node: GameplayTagNode) {
        let newPrefix = composeName(parent: node.parent?.tag.name, leaf: node.tag.leafName)
        let oldPrefix = node.tag.name
        node.tag.name = newPrefix
        GameplayTagNode.forEach(node) { child in
            if child.tag.name.hasPrefix(oldPrefix + ".") {
                let rest = child.tag.name.dropFirst(oldPrefix.count + 1)
                child.tag.name = newPrefix + "." + rest
            }
        }
    }

    private func makeNameUnique(_ node: GameplayTagNode) {
        let siblings: [GameplayTagNode] = node.parent?.children ?? roots
        let conflicts = siblings.filter { $0.id != node.id && $0.tag.name == node.tag.name }
        guard !conflicts.isEmpty else { return }
        var i = 2
        while true {
            let candidate = "\(node.tag.name)_\(i)"
            if !siblings.contains(where: { $0.id != node.id && $0.tag.name == candidate }) {
                node.tag.name = candidate
                updatePathPrefix(node)
                return
            }
            i += 1
        }
    }

    private func fixAllParents() {
        func walk(_ list: [GameplayTagNode], parent: GameplayTagNode?) {
            for n in list {
                n.parent = parent
                walk(n.children, parent: n)
            }
        }
        walk(roots, parent: nil)
    }

    // MARK: - 撤销 / 重做

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        pushRedo(for: entry)
        applyUndoEntry(entry)
        markDirty()
    }

    func redo() {
        guard let entry = redoStack.popLast() else { return }
        pushUndo(for: entry, isRedo: true)
        applyRedoEntry(entry)
        markDirty()
    }

    // MARK: - 内部

    private func applyTags(_ tags: [GameplayTag], recordHistory shouldRecord: Bool) {
        if shouldRecord {
            recordTreeHistory()
        }
        let built = TagTreeBuilder.build(from: tags)
        self.roots = built
        rebuildDerivedState()
    }

    private func recordTreeHistory() {
        undoStack.append(.tree(snapshotTags()))
        trimHistory()
        redoStack.removeAll()
    }

    private func recordMetadataHistory(node: GameplayTagNode) {
        undoStack.append(.metadata(nodeID: node.id, snapshot: node.tag))
        trimHistory()
        redoStack.removeAll()
    }

    private func trimHistory() {
        if undoStack.count > maxHistory { undoStack.removeFirst() }
    }

    private func snapshotTags() -> [GameplayTag] { flatTags }

    private func pushRedo(for undone: UndoEntry) {
        switch undone {
        case .tree:
            redoStack.append(.tree(snapshotTags()))
        case .metadata(let nodeID, _):
            guard let node = findNode(id: nodeID) else { return }
            redoStack.append(.metadata(nodeID: nodeID, snapshot: node.tag))
        }
    }

    private func pushUndo(for redone: UndoEntry, isRedo: Bool) {
        switch redone {
        case .tree:
            undoStack.append(.tree(snapshotTags()))
        case .metadata(let nodeID, _):
            guard let node = findNode(id: nodeID) else { return }
            undoStack.append(.metadata(nodeID: nodeID, snapshot: node.tag))
        }
        if isRedo { trimHistory() }
    }

    private func applyUndoEntry(_ entry: UndoEntry) {
        switch entry {
        case .tree(let tags):
            applyTags(tags, recordHistory: false)
        case .metadata(let nodeID, let snapshot):
            applyMetadataSnapshot(nodeID: nodeID, snapshot: snapshot)
        }
    }

    private func applyRedoEntry(_ entry: UndoEntry) {
        applyUndoEntry(entry)
    }

    private func applyMetadataSnapshot(nodeID: UUID, snapshot: GameplayTag) {
        guard let node = findNode(id: nodeID) else { return }
        node.tag.devComment = snapshot.devComment
        if let idx = flatTags.firstIndex(where: { $0.id == nodeID }) {
            flatTags[idx].devComment = snapshot.devComment
        }
        invalidateSearchCache()
        exportRevision &+= 1
        contentRevision &+= 1
    }

    private func markDirty() {
        isDirty = true
    }

    private func invalidateSearchCache() {
        searchCacheQuery = ""
        searchCacheVisible = nil
    }

    private func rebuildDerivedState() {
        invalidateSearchCache()
        exportRevision &+= 1

        var flat: [GameplayTag] = []
        var index: [UUID: GameplayTagNode] = [:]
        var issues: [UUID: GameplayTag.ValidationError] = [:]
        var nameCount: [String: Int] = [:]

        for node in roots {
            collect(node, into: &flat, index: &index, issues: &issues, nameCount: &nameCount)
        }

        var dupIDs: Set<UUID> = []
        for n in flat where (nameCount[n.name] ?? 0) > 1 {
            dupIDs.insert(n.id)
        }

        flatTags = flat
        nodeByID = index
        validationIssues = issues
        duplicateIDs = dupIDs
        selectedNodeIDs = selectedNodeIDs.filter { index[$0] != nil }
        contentRevision &+= 1
    }

    private func collect(
        _ node: GameplayTagNode,
        into flat: inout [GameplayTag],
        index: inout [UUID: GameplayTagNode],
        issues: inout [UUID: GameplayTag.ValidationError],
        nameCount: inout [String: Int]
    ) {
        flat.append(node.tag)
        index[node.id] = node
        if let err = node.tag.validate() {
            issues[node.id] = err
        }
        nameCount[node.tag.name, default: 0] += 1
        for child in node.children {
            collect(child, into: &flat, index: &index, issues: &issues, nameCount: &nameCount)
        }
    }

    func findNode(id: GameplayTagNode.ID) -> GameplayTagNode? {
        nodeByID[id]
    }

    private func uniqueName(based leaf: String, parentName: String?) -> String {
        let base = composeName(parent: parentName, leaf: leaf)
        guard findNode(byFullName: base) != nil else { return base }
        var i = 2
        while true {
            let candidate = "\(base)_\(i)"
            if findNode(byFullName: candidate) == nil { return candidate }
            i += 1
        }
    }

    private func findNode(byFullName name: String) -> GameplayTagNode? {
        GameplayTagNode.firstNode(in: roots, where: { $0.tag.name == name })
    }

    private func composeName(parent: String?, leaf: String) -> String {
        if let p = parent, !p.isEmpty { return p + "." + leaf }
        return leaf
    }

    private func matchesSearch(_ node: GameplayTagNode, query: String) -> Bool {
        if node.tag.name.range(of: query, options: .caseInsensitive) != nil { return true }
        if node.tag.devComment.range(of: query, options: .caseInsensitive) != nil { return true }
        return false
    }
}
