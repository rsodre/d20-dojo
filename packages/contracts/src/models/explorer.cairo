use d20::types::index::Skill;
use d20::types::items::{WeaponType, ArmorType};
use d20::types::explorer_class::ExplorerClass;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerStats {
    #[key]
    pub explorer_id: u128,
    // Ability scores (each 3-20)
    pub strength: u8,
    pub dexterity: u8,
    pub constitution: u8,
    pub intelligence: u8,
    pub wisdom: u8,
    pub charisma: u8,
    // Progression
    pub level: u8,
    pub xp: u32,
    pub class: ExplorerClass,
    // Achievements
    pub temples_conquered: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerHealth {
    #[key]
    pub explorer_id: u128,
    pub current_hp: i16,
    pub max_hp: u16,
    pub is_dead: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerCombat {
    #[key]
    pub explorer_id: u128,
    pub armor_class: u8,
    // Class resources
    pub spell_slots_1: u8,
    pub spell_slots_2: u8,
    pub spell_slots_3: u8,
    pub second_wind_used: bool,
    pub action_surge_used: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerInventory {
    #[key]
    pub explorer_id: u128,
    pub primary_weapon: WeaponType,
    pub secondary_weapon: WeaponType,
    pub armor: ArmorType,
    pub has_shield: bool,
    pub gold: u32,
    pub potions: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerPosition {
    #[key]
    pub explorer_id: u128,
    pub temple_id: u128,
    pub chamber_id: u32,
    pub in_combat: bool,
    pub combat_monster_id: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerSkills {
    #[key]
    pub explorer_id: u128,
    // Proficiency flags for each skill
    pub athletics: bool,
    pub stealth: bool,
    pub perception: bool,
    pub persuasion: bool,
    pub arcana: bool,
    pub acrobatics: bool,
    // Expertise (double proficiency, Rogue feature)
    pub expertise_1: Skill,
    pub expertise_2: Skill,
}
