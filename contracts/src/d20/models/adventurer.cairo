use d20::d20::types::items::{WeaponType, ArmorType};
use d20::d20::types::adventurer_class::AdventurerClass;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdventurerStats {
    #[key]
    pub adventurer_id: u128,
    pub abilities: AbilityScore,
    // Progression
    pub level: u8,
    pub xp: u32,
    pub adventurer_class: AdventurerClass,
    // Achievements
    pub dungeons_conquered: u16,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, DojoStore, Default)]
pub struct AbilityScore {
    pub strength: u8,
    pub dexterity: u8,
    pub constitution: u8,
    pub intelligence: u8,
    pub wisdom: u8,
    pub charisma: u8,
}


// #[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
// pub enum AbilityScore {
//     #[default]
//     None,
//     Strength,
//     Dexterity,
//     Constitution,
//     Intelligence,
//     Wisdom,
//     Charisma,
// }

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdventurerHealth {
    #[key]
    pub adventurer_id: u128,
    pub current_hp: i16,
    pub max_hp: u16,
    pub is_dead: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdventurerCombat {
    #[key]
    pub adventurer_id: u128,
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
pub struct AdventurerInventory {
    #[key]
    pub adventurer_id: u128,
    pub primary_weapon: WeaponType,
    pub secondary_weapon: WeaponType,
    pub armor: ArmorType,
    pub has_shield: bool,
    pub gold: u32,
    pub potions: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdventurerPosition {
    #[key]
    pub adventurer_id: u128,
    pub dungeon_id: u128,
    pub chamber_id: u32,
    pub in_combat: bool,
    pub combat_monster_id: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct AdventurerSkills {
    #[key]
    pub adventurer_id: u128,
    // Proficiency flags for each skill
    pub skills: SkillsSet,
    // Expertise (double proficiency, Rogue feature)
    pub expertise_1: Skill,
    pub expertise_2: Skill,
}

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

#[derive(Copy, Drop, Serde, IntrospectPacked, DojoStore, Default)]
pub struct SkillsSet {
    pub athletics: bool,
    pub stealth: bool,
    pub perception: bool,
    pub persuasion: bool,
    pub arcana: bool,
    pub acrobatics: bool,
}
