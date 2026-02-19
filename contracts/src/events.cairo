use starknet::ContractAddress;
use d20::types::index::{CombatAction, ChamberType};
use d20::types::explorer_class::ExplorerClass;
use d20::types::monster::MonsterType;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExplorerMinted {
    #[key]
    pub explorer_id: u128,
    pub class: ExplorerClass,
    pub player: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct CombatResult {
    #[key]
    pub explorer_id: u128,
    pub action: CombatAction,
    pub roll: u8,
    pub damage_dealt: u16,
    pub damage_taken: u16,
    pub monster_killed: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExplorerDied {
    #[key]
    pub explorer_id: u128,
    pub temple_id: u128,
    pub chamber_id: u32,
    pub killed_by: MonsterType,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ChamberRevealed {
    #[key]
    pub temple_id: u128,
    pub chamber_id: u32,
    pub chamber_type: ChamberType,
    pub yonder: u8,
    pub revealed_by: u128,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct LevelUp {
    #[key]
    pub explorer_id: u128,
    pub new_level: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct BossDefeated {
    #[key]
    pub temple_id: u128,
    pub explorer_id: u128,
    pub monster_type: MonsterType,
}
