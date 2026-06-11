import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 树节点拖拽载荷。
struct TagDragPayload: Codable, Hashable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}

/// 树侧边栏拖拽 / 放置逻辑。
enum TagDropAction {
    case child
    case beforeSibling
    case afterSibling
}

extension TagStore {
    @discardableResult
    func applyDrop(draggedID: UUID, onto target: GameplayTagNode, action: TagDropAction) -> Bool {
        guard draggedID != target.id, findNode(id: draggedID) != nil else { return false }
        if target.contains(id: draggedID) { return false }

        switch action {
        case .child:
            move(id: draggedID, toParent: target.id)
        case .beforeSibling:
            move(id: draggedID, toParent: target.parent?.id, insertBefore: target.id)
        case .afterSibling:
            reorder(id: draggedID, after: target.id)
        }

        selectNode(draggedID)
        return true
    }

    @discardableResult
    func applyDropToRoot(draggedID: UUID) -> Bool {
        guard findNode(id: draggedID) != nil else { return false }
        move(id: draggedID, toParent: nil)
        selectNode(draggedID)
        return true
    }
}

func tagDropAction(for target: GameplayTagNode, modifiers: EventModifiers) -> TagDropAction {
    if modifiers.contains(.option) { return .beforeSibling }
    if modifiers.contains(.shift) { return .afterSibling }
    return .child
}

/// 行内拖拽手柄 — 仅在此处启动拖拽,避免与 List 选择冲突。
struct TagDragHandle: View {
    let nodeID: UUID

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
            .help("拖拽以移动 Tag · Option 同级前 · Shift 同级后")
            .draggable(TagDragPayload(id: nodeID))
    }
}

func currentDropModifiers() -> EventModifiers {
    var modifiers = EventModifiers()
    if NSEvent.modifierFlags.contains(.option) { modifiers.insert(.option) }
    if NSEvent.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
    if NSEvent.modifierFlags.contains(.command) { modifiers.insert(.command) }
    if NSEvent.modifierFlags.contains(.control) { modifiers.insert(.control) }
    return modifiers
}

struct TagDropSurface: ViewModifier {
    let highlighted: Bool
    let onTargetChange: (Bool) -> Void
    let onDrop: (TagDragPayload, EventModifiers) -> Bool

    func body(content: Content) -> some View {
        content
            .background(highlighted ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .dropDestination(for: TagDragPayload.self) { items, _ in
                guard let payload = items.first else { return false }
                return onDrop(payload, currentDropModifiers())
            } isTargeted: { onTargetChange($0) }
    }
}

extension View {
    func tagDropSurface(
        highlighted: Bool,
        onTargetChange: @escaping (Bool) -> Void,
        onDrop: @escaping (TagDragPayload, EventModifiers) -> Bool
    ) -> some View {
        modifier(TagDropSurface(highlighted: highlighted, onTargetChange: onTargetChange, onDrop: onDrop))
    }
}
