import Foundation

/// 内置示例数据(UE5 DataTable CSV)。
/// 内容来自 bundle 中的 `Resources/sample.csv`。
enum SampleCSV {
    static var content: String {
        if let url = Bundle.module.url(forResource: "sample", withExtension: "csv"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return fallback
    }

    /// bundle 缺失时的兜底(与 sample.csv 保持一致)。
    private static let fallback = """
    Name,Tag,DevComment
    0,Character.Stats.Health,生命值
    1,Character.Stats.Mana,魔法值
    2,Character.Stats.Stamina,体力
    3,Combat.Damage.Melee,近战伤害
    4,Combat.Damage.Ranged,远程伤害
    5,Combat.Damage.Magic,魔法伤害
    6,Combat.Defense.Physical,物理防御
    7,Combat.Defense.Magical,魔法防御
    8,Status.Burning,燃烧
    9,Status.Frozen,冰冻
    10,Status.Poisoned,中毒
    11,Status.Stunned,眩晕
    12,Ability.Fireball,火球术
    13,Ability.Heal,治疗术
    14,Ability.Shield,护盾
    """
}
