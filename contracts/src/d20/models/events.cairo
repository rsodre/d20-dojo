use starknet::ContractAddress;
use d20::d20::types::index::{CombatAction, ChamberType};
use d20::d20::types::adventurer_class::AdventurerClass;
use d20::d20::models::monster::MonsterType;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdventurerMinted {
    #[key]
    pub adventurer_id: u128,
    pub adventurer_class: AdventurerClass,
    pub player: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct AdventurerDied {
    #[key]
    pub adventurer_id: u128,
    pub dungeon_id: u128,
    pub chamber_id: u32,
    pub killed_by: MonsterType,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ChamberRevealed {
    #[key]
    pub dungeon_id: u128,
    pub chamber_id: u32,
    pub chamber_type: ChamberType,
    pub yonder: u8,
    pub revealed_by: u128,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct CombatResult {
    #[key]
    pub adventurer_id: u128,
    pub action: CombatAction,
    pub roll: u8,
    pub damage_dealt: u16,
    pub damage_taken: u16,
    pub monster_killed: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct BossDefeated {
    #[key]
    pub dungeon_id: u128,
    pub adventurer_id: u128,
    pub monster_type: MonsterType,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct LevelUp {
    #[key]
    pub adventurer_id: u128,
    pub new_level: u8,
}
