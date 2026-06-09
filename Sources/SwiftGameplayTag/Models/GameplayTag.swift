import Foundation

/// 单个 GameplayTag 的元数据。
///
/// `name` 是完整层级路径,用 `.` 分隔,例如 `Combat.Damage.Melee`。
struct GameplayTag: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var devComment: String
    var category: String?
    var isHidden: Bool

    init(
        id: UUID = UUID(),
        name: String,
        devComment: String = "",
        category: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.devComment = devComment
        self.category = category
        self.isHidden = isHidden
    }

    /// 路径分段。
    var segments: [String] {
        name.split(separator: ".").map(String.init)
    }

    /// 末段名(只显示叶子段)。
    var leafName: String {
        segments.last ?? name
    }
}

extension GameplayTag {
    /// 路径合法性:不允许空、不允许包含 `,` `;` `"` `\n` `\r`。
    enum ValidationError: LocalizedError, Equatable {
        case emptyName
        case emptySegment
        case illegalCharacter(Character, in: String)
        case reservedCharacter(Character, in: String)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "名称不能为空"
            case .emptySegment:
                return "路径中不能有连续的点(例如 `a..b`)"
            case .illegalCharacter(let ch, _):
                return "名称包含非法字符: `\(ch)`"
            case .reservedCharacter(let ch, _):
                return "名称不能包含保留字符: `\(ch)`"
            }
        }
    }

    /// 校验完整路径是否符合 GameplayTag 命名规则。
    func validate() -> ValidationError? {
        Self.validate(name: name)
    }

    static func validate(name: String) -> ValidationError? {
        if name.isEmpty { return .emptyName }
        if name.hasPrefix(".") || name.hasSuffix(".") { return .emptySegment }

        let segments = name.split(separator: ".", omittingEmptySubsequences: false)
        if segments.contains(where: { $0.isEmpty }) {
            return .emptySegment
        }

        let illegalInSegment: Set<Character> = [",", ";", "\"", "\n", "\r", "\t"]
        for segment in segments {
            for ch in segment {
                if ch == "." {
                    return .reservedCharacter(ch, in: name)
                }
                if illegalInSegment.contains(ch) {
                    return .illegalCharacter(ch, in: name)
                }
            }
        }
        return nil
    }
}
