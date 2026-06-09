import Foundation

/// 树节点。`name` 始终是完整路径,`parent` 用弱引用避免循环。
/// `id` 始终跟随 `tag.id`,避免构建树时替换 tag 后左右面板 id 不一致。
final class GameplayTagNode: Identifiable {
    var tag: GameplayTag
    var children: [GameplayTagNode]
    weak var parent: GameplayTagNode?

    var id: UUID { tag.id }

    init(tag: GameplayTag, children: [GameplayTagNode] = [], parent: GameplayTagNode? = nil) {
        self.tag = tag
        self.children = children
        self.parent = parent
    }

    var isLeaf: Bool { children.isEmpty }

    /// 仅显示最后一段(在树里看起来更紧凑)。
    var displayName: String { tag.leafName }

    /// 子树中所有 GameplayTag 的扁平列表(包含中间节点)。
    func collectTags() -> [GameplayTag] {
        var out: [GameplayTag] = [tag]
        for child in children { out.append(contentsOf: child.collectTags()) }
        return out
    }

    /// 子树中是否包含给定 id 的节点(包含自身)。
    func contains(id target: UUID) -> Bool {
        if id == target { return true }
        for c in children where c.contains(id: target) { return true }
        return false
    }
}

/// 整棵树的递归工具。
extension GameplayTagNode {
    static func forEach(in roots: [GameplayTagNode],
                        _ body: (GameplayTagNode) -> Void) {
        for root in roots { forEach(root, body) }
    }

    static func forEach(_ node: GameplayTagNode,
                        _ body: (GameplayTagNode) -> Void) {
        body(node)
        for child in node.children { forEach(child, body) }
    }

    static func firstNode(in roots: [GameplayTagNode],
                          where predicate: (GameplayTagNode) -> Bool) -> GameplayTagNode? {
        for root in roots {
            if let hit = firstNode(root, where: predicate) { return hit }
        }
        return nil
    }

    static func firstNode(_ node: GameplayTagNode,
                          where predicate: (GameplayTagNode) -> Bool) -> GameplayTagNode? {
        if predicate(node) { return node }
        for child in node.children {
            if let hit = firstNode(child, where: predicate) { return hit }
        }
        return nil
    }
}

extension GameplayTagNode: Equatable {
    static func == (lhs: GameplayTagNode, rhs: GameplayTagNode) -> Bool {
        lhs.id == rhs.id
    }
}

extension GameplayTagNode: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
