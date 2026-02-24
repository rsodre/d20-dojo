
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

