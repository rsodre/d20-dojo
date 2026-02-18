#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum WeaponType {
    #[default]
    None,
    Longsword,    // 1d8 slashing, melee, STR
    Dagger,       // 1d4 piercing, melee/thrown, DEX or STR
    Shortbow,     // 1d6 piercing, ranged, DEX
    Greataxe,     // 1d12 slashing, melee, STR, two-handed
    Staff,        // 1d6 bludgeoning, melee, STR
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ArmorType {
    #[default]
    None,         // AC 10 + DEX mod
    Leather,      // AC 11 + DEX mod
    ChainMail,    // AC 16 (no DEX bonus)
}

#[generate_trait]
pub impl WeaponTypeImpl of WeaponTypeTrait {
    fn damage_sides(self: WeaponType) -> u8 {
        match self {
            WeaponType::Longsword => 8,
            WeaponType::Dagger => 4,
            WeaponType::Shortbow => 6,
            WeaponType::Greataxe => 12,
            WeaponType::Staff => 6,
            WeaponType::None => 4,
        }
    }

    fn damage_count(self: WeaponType) -> u8 {
        match self {
            WeaponType::None => 0,
            _ => 1,
        }
    }

    fn uses_dex(self: WeaponType) -> bool {
        match self {
            WeaponType::Dagger => true,
            WeaponType::Shortbow => true,
            _ => false,
        }
    }
}

#[generate_trait]
pub impl ArmorImpl of ArmorTrait {
    fn base_ac(self: ArmorType) -> u8 {
        match self {
            ArmorType::None => 10,
            ArmorType::Leather => 11,
            ArmorType::ChainMail => 16,
        }
    }

    fn allows_dex_bonus(self: ArmorType) -> bool {
        match self {
            ArmorType::ChainMail => false,
            _ => true,
        }
    }
}
