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

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ItemType {
    #[default]
    None,
    HealthPotion,
}

use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use d20::d20::models::character::{CharacterStats, CharacterInventory};
use d20::utils::dice::roll_dice;
use d20::utils::seeder::Seeder;

#[generate_trait]
pub impl ItemTypeImpl of ItemTypeTrait {
    fn resolve(
        self: ItemType,
        ref world: WorldStorage,
        ref seeder: Seeder,
        character_id: u128,
        stats: CharacterStats,
    ) -> u8 {
        match self {
            ItemType::None => {
                assert(false, 'no item specified');
                0
            },
            ItemType::HealthPotion => {
                let mut inventory: CharacterInventory = world.read_model(character_id);
                assert(inventory.potions > 0, 'no potions remaining');
                inventory.potions -= 1;
                world.write_model(@inventory);

                // Heal 2d4+2
                let raw_heal: u16 = roll_dice(ref seeder, 4, 2);
                let heal_total: u16 = raw_heal + 2;

                let new_hp_i16: i16 = stats.current_hp + heal_total.try_into().unwrap();
                let new_hp: i16 = if new_hp_i16 > stats.max_hp.try_into().unwrap() {
                    stats.max_hp.try_into().unwrap()
                } else {
                    new_hp_i16
                };

                let mut healed_stats = stats;
                healed_stats.current_hp = new_hp;
                healed_stats.is_dead = false;
                world.write_model(@healed_stats);

                raw_heal.try_into().unwrap()
            },
        }
    }
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
