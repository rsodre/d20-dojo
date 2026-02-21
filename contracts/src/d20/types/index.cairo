
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
