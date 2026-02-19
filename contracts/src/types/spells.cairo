#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum SpellId {
    #[default]
    None,
    // Cantrips
    FireBolt,
    MageHand,
    Light,
    // 1st level
    MagicMissile,
    ShieldSpell,
    Sleep,
    // 2nd level
    ScorchingRay,
    MistyStep,
    // 3rd level
    Fireball,
}

#[generate_trait]
pub impl SpellImpl of SpellIdTrait {
    fn level(self: SpellId) -> u8 {
        match self {
            SpellId::None => 0,
            // Cantrips
            SpellId::FireBolt => 0,
            SpellId::MageHand => 0,
            SpellId::Light => 0,
            // 1st level
            SpellId::MagicMissile => 1,
            SpellId::ShieldSpell => 1,
            SpellId::Sleep => 1,
            // 2nd level
            SpellId::ScorchingRay => 2,
            SpellId::MistyStep => 2,
            // 3rd level
            SpellId::Fireball => 3,
        }
    }
}
