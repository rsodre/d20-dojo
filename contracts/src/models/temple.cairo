use d20::types::index::ChamberType;
use d20::types::items::{WeaponType, ArmorType};
use d20::types::monster::MonsterType;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TempleState {
    #[key]
    pub temple_id: u128,
    pub difficulty_tier: u8,
    pub next_chamber_id: u32,
    pub boss_chamber_id: u32,
    pub boss_alive: bool,
    pub max_yonder: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Chamber {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    pub chamber_type: ChamberType,
    pub yonder: u8,
    pub exit_count: u8,
    pub is_revealed: bool,
    pub treasure_looted: bool,
    pub trap_disarmed: bool,
    pub trap_dc: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MonsterInstance {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    #[key]
    pub monster_id: u32,
    pub monster_type: MonsterType,
    pub current_hp: i16,
    pub max_hp: u16,
    pub is_alive: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ChamberExit {
    #[key]
    pub temple_id: u128,
    #[key]
    pub from_chamber_id: u32,
    #[key]
    pub exit_index: u8,
    pub to_chamber_id: u32,
    pub is_discovered: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct FallenExplorer {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    #[key]
    pub fallen_index: u32,
    pub explorer_id: u128,
    // Dropped loot
    pub dropped_weapon: WeaponType,
    pub dropped_armor: ArmorType,
    pub dropped_gold: u32,
    pub dropped_potions: u8,
    pub is_looted: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ChamberFallenCount {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    pub count: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerTempleProgress {
    #[key]
    pub explorer_id: u128,
    #[key]
    pub temple_id: u128,
    pub chambers_explored: u16,
    pub xp_earned: u32,
}
