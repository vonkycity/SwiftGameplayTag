import Foundation

/// 内置示例数据(扩展 CSV 格式,含 Hidden 字段)。
/// 启动时 / 「Load Sample」时使用。
enum SampleCSV {
    static let content: String = """
    Name,DevComment,Category,Hidden
    Character.Stats.Health,生命值,Stats,false
    Character.Stats.Mana,魔法值,Stats,false
    Character.Stats.Stamina,体力,Stats,false
    Combat.Damage.Melee,近战伤害,Combat,false
    Combat.Damage.Ranged,远程伤害,Combat,false
    Combat.Damage.Magic,魔法伤害,Combat,false
    Combat.Defense.Physical,物理防御,Combat,false
    Combat.Defense.Magical,魔法防御,Combat,false
    Status.Burning,燃烧,Status,false
    Status.Frozen,冰冻,Status,false
    Status.Poisoned,中毒,Status,false
    Status.Stunned,眩晕,Status,false
    Ability.Fireball,火球术,Ability,false
    Ability.Heal,治疗术,Ability,false
    Ability.Shield,护盾,Ability,false
    """
}
