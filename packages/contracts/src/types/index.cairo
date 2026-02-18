
#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum Skill {
    #[default]
    None,
    Athletics,
    Stealth,
    Perception,
    Persuasion,
    Arcana,
    Acrobatics,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AbilityScore {
    #[default]
    None,
    Strength,
    Dexterity,
    Constitution,
    Intelligence,
    Wisdom,
    Charisma,
}



#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum CombatAction {
    #[default]
    None,
    Attack,
    CastSpell,
    UseItem,
    Flee,
    Dodge,
    SecondWind,
    CunningAction,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ItemType {
    #[default]
    None,
    HealthPotion,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DamageType {
    #[default]
    None,
    Slashing,
    Piercing,
    Bludgeoning,
    Fire,
    Cold,
    Lightning,
    Force,
    Necrotic,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ChamberType {
    #[default]
    None,
    Entrance,
    Empty,
    Monster,
    Treasure,
    Trap,
    Boss,
}
