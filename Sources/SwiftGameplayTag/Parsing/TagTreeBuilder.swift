import Foundation

/// 把扁平的 `GameplayTag` 列表组装成树。
/// - 同一父级下不会产生同名子节点:重复节点会被合并,后者的元数据覆盖前者。
enum TagTreeBuilder {
    static func build(from tags: [GameplayTag]) -> [GameplayTagNode] {
        // 用哨兵节点,它的 children 数组就是最终的 roots。
        let sentinel = GameplayTagNode(tag: GameplayTag(name: ""))

        for tag in tags {
            let parts = tag.name.split(separator: ".").map(String.init)
            guard !parts.isEmpty else { continue }

            var parent = sentinel
            var path: [String] = []

            for (idx, part) in parts.enumerated() {
                path.append(part)
                let fullPath = path.joined(separator: ".")
                let node: GameplayTagNode
                if let existing = parent.children.first(where: { $0.tag.name == fullPath }) {
                    node = existing
                } else {
                    let placeholder = GameplayTag(name: fullPath)
                    node = GameplayTagNode(tag: placeholder)
                    parent.children.append(node)
                }
                if idx == parts.count - 1 {
                    node.tag = tag
                }
                parent = node
            }
        }

        func fixParent(_ list: [GameplayTagNode], parent: GameplayTagNode?) {
            for n in list {
                n.parent = parent
                fixParent(n.children, parent: n)
            }
        }
        let roots = sentinel.children
        fixParent(roots, parent: nil)
        return roots
    }
}
