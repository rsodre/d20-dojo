
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MonsterInstance {
    #[key]
    pub dungeon_id: u128,
    #[key]
    pub chamber_id: u32,
    #[key]
    pub monster_id: u32,
    pub monster_type: MonsterType,
    pub current_hp: i16,
    pub max_hp: u16,
    pub is_alive: bool,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum MonsterType {
    #[default]
    None,
    PoisonousSnake,
    Skeleton,
    Shadow,
    AnimatedArmor,
    Gargoyle,
    Mummy,
    Wraith,
}

/// Compile-time monster stat template. These are pure data — not Dojo models.
/// When a chamber is generated, a MonsterInstance model is created from these stats.
#[derive(Copy, Drop)]
pub struct MonsterStats {
    pub monster_type: MonsterType,
    pub ac: u8,
    pub hp: u16,
    pub attack_bonus: i8,
    pub damage_dice_sides: u8,
    pub damage_dice_count: u8,
    pub damage_bonus: i8,
    pub num_attacks: u8,       // multiattack: how many attacks per turn
    pub xp_reward: u32,
    pub cr_x4: u8,             // CR * 4 (integer-safe: CR 1/8=0, 1/4=1, 1/2=2, 1=4, etc.)
    // Ability scores (used for saving throws and contested checks)
    pub strength: u8,
    pub dexterity: u8,
    pub constitution: u8,
    pub intelligence: u8,
    pub wisdom: u8,
    pub charisma: u8,
    // Special ability DCs (0 = no special)
    pub special_save_dc: u8,
    pub special_damage_dice_sides: u8,
    pub special_damage_dice_count: u8,
}

/// Pure lookup function — returns compile-time stats for each MonsterType.
/// Returns a zero-stat struct for MonsterType::None.
#[generate_trait]
pub impl MonsterTypeImpl of MonsterTypeTrait {
    fn get_stats(self: MonsterType) -> MonsterStats {
        match self {
            MonsterType::None => MonsterStats {
                monster_type: MonsterType::None,
                ac: 0, hp: 0, attack_bonus: 0,
                damage_dice_sides: 0, damage_dice_count: 0, damage_bonus: 0,
                num_attacks: 0, xp_reward: 0, cr_x4: 0,
                strength: 0, dexterity: 0, constitution: 0,
                intelligence: 0, wisdom: 0, charisma: 0,
                special_save_dc: 0, special_damage_dice_sides: 0, special_damage_dice_count: 0,
            },
            MonsterType::PoisonousSnake => MonsterStats {
                monster_type: MonsterType::PoisonousSnake,
                ac: 13, hp: 2, attack_bonus: 5,
                damage_dice_sides: 1, damage_dice_count: 1, damage_bonus: 0,
                num_attacks: 1, xp_reward: 25, cr_x4: 0,
                strength: 2, dexterity: 16, constitution: 11,
                intelligence: 1, wisdom: 10, charisma: 3,
                special_save_dc: 10,           // DC 10 CON save
                special_damage_dice_sides: 4,  // 2d4 poison damage
                special_damage_dice_count: 2,
            },
            MonsterType::Skeleton => MonsterStats {
                monster_type: MonsterType::Skeleton,
                ac: 13, hp: 13, attack_bonus: 4,
                damage_dice_sides: 6, damage_dice_count: 1, damage_bonus: 2,
                num_attacks: 1, xp_reward: 50, cr_x4: 1,
                strength: 10, dexterity: 14, constitution: 15,
                intelligence: 6, wisdom: 8, charisma: 5,
                special_save_dc: 0, special_damage_dice_sides: 0, special_damage_dice_count: 0,
            },
            MonsterType::Shadow => MonsterStats {
                monster_type: MonsterType::Shadow,
                ac: 12, hp: 16, attack_bonus: 4,
                damage_dice_sides: 6, damage_dice_count: 2, damage_bonus: 2,
                num_attacks: 1, xp_reward: 100, cr_x4: 2,
                strength: 6, dexterity: 14, constitution: 13,
                intelligence: 6, wisdom: 10, charisma: 8,
                special_save_dc: 0,            // STR drain is automatic on hit
                special_damage_dice_sides: 4,  // 1d4 STR drain
                special_damage_dice_count: 1,
            },
            MonsterType::AnimatedArmor => MonsterStats {
                monster_type: MonsterType::AnimatedArmor,
                ac: 18, hp: 33, attack_bonus: 4,
                damage_dice_sides: 6, damage_dice_count: 1, damage_bonus: 2,
                num_attacks: 2, xp_reward: 200, cr_x4: 4,  // multiattack: 2 slams
                strength: 14, dexterity: 11, constitution: 13,
                intelligence: 1, wisdom: 3, charisma: 1,
                special_save_dc: 0, special_damage_dice_sides: 0, special_damage_dice_count: 0,
            },
            MonsterType::Gargoyle => MonsterStats {
                monster_type: MonsterType::Gargoyle,
                ac: 15, hp: 52, attack_bonus: 4,
                damage_dice_sides: 6, damage_dice_count: 1, damage_bonus: 2,
                num_attacks: 2, xp_reward: 450, cr_x4: 8,  // multiattack: bite + claws
                strength: 15, dexterity: 11, constitution: 16,
                intelligence: 6, wisdom: 11, charisma: 7,
                special_save_dc: 0, special_damage_dice_sides: 0, special_damage_dice_count: 0,
            },
            MonsterType::Mummy => MonsterStats {
                monster_type: MonsterType::Mummy,
                ac: 11, hp: 58, attack_bonus: 5,
                damage_dice_sides: 6, damage_dice_count: 2, damage_bonus: 3,
                num_attacks: 1, xp_reward: 700, cr_x4: 12,
                strength: 16, dexterity: 8, constitution: 15,
                intelligence: 6, wisdom: 10, charisma: 12,
                special_save_dc: 12,           // DC 12 CON save (mummy rot)
                special_damage_dice_sides: 0,
                special_damage_dice_count: 0,
            },
            MonsterType::Wraith => MonsterStats {
                monster_type: MonsterType::Wraith,
                ac: 13, hp: 67, attack_bonus: 6,
                damage_dice_sides: 8, damage_dice_count: 4, damage_bonus: 3,
                num_attacks: 1, xp_reward: 1800, cr_x4: 20,
                strength: 6, dexterity: 16, constitution: 16,
                intelligence: 12, wisdom: 14, charisma: 15,
                special_save_dc: 14,           // DC 14 CON save (max HP reduction)
                special_damage_dice_sides: 0,
                special_damage_dice_count: 0,
            },
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::MonsterTypeTrait;
    use super::MonsterType;

    #[test]
    fn test_none_returns_zero_stats() {
        let stats = MonsterType::None.get_stats();
        assert(stats.ac == 0, 'none ac should be 0');
        assert(stats.hp == 0, 'none hp should be 0');
        assert(stats.xp_reward == 0, 'none xp should be 0');
    }

    #[test]
    fn test_poisonous_snake_stats() {
        let stats = MonsterType::PoisonousSnake.get_stats();
        assert(stats.ac == 13, 'snake ac should be 13');
        assert(stats.hp == 2, 'snake hp should be 2');
        assert(stats.attack_bonus == 5, 'snake atk should be +5');
        assert(stats.xp_reward == 25, 'snake xp should be 25');
        assert(stats.cr_x4 == 0, 'snake cr_x4 should be 0');
        assert(stats.dexterity == 16, 'snake dex should be 16');
        assert(stats.special_save_dc == 10, 'snake special dc = 10');
    }

    #[test]
    fn test_skeleton_stats() {
        let stats = MonsterType::Skeleton.get_stats();
        assert(stats.ac == 13, 'skeleton ac should be 13');
        assert(stats.hp == 13, 'skeleton hp should be 13');
        assert(stats.attack_bonus == 4, 'skeleton atk should be +4');
        assert(stats.damage_dice_sides == 6, 'skeleton dmg d6');
        assert(stats.damage_bonus == 2, 'skeleton dmg +2');
        assert(stats.xp_reward == 50, 'skeleton xp should be 50');
        assert(stats.cr_x4 == 1, 'skeleton cr_x4 should be 1');
    }

    #[test]
    fn test_shadow_stats() {
        let stats = MonsterType::Shadow.get_stats();
        assert(stats.ac == 12, 'shadow ac should be 12');
        assert(stats.hp == 16, 'shadow hp should be 16');
        assert(stats.xp_reward == 100, 'shadow xp should be 100');
        assert(stats.cr_x4 == 2, 'shadow cr_x4 should be 2');
        assert(stats.damage_dice_count == 2, 'shadow 2d6');
    }

    #[test]
    fn test_animated_armor_stats() {
        let stats = MonsterType::AnimatedArmor.get_stats();
        assert(stats.ac == 18, 'armor ac should be 18');
        assert(stats.hp == 33, 'armor hp should be 33');
        assert(stats.num_attacks == 2, 'armor multiattack = 2');
        assert(stats.xp_reward == 200, 'armor xp should be 200');
        assert(stats.cr_x4 == 4, 'armor cr_x4 should be 4');
    }

    #[test]
    fn test_gargoyle_stats() {
        let stats = MonsterType::Gargoyle.get_stats();
        assert(stats.ac == 15, 'gargoyle ac should be 15');
        assert(stats.hp == 52, 'gargoyle hp should be 52');
        assert(stats.num_attacks == 2, 'gargoyle multiattack = 2');
        assert(stats.xp_reward == 450, 'gargoyle xp should be 450');
        assert(stats.cr_x4 == 8, 'gargoyle cr_x4 should be 8');
    }

    #[test]
    fn test_mummy_stats() {
        let stats = MonsterType::Mummy.get_stats();
        assert(stats.ac == 11, 'mummy ac should be 11');
        assert(stats.hp == 58, 'mummy hp should be 58');
        assert(stats.attack_bonus == 5, 'mummy atk should be +5');
        assert(stats.xp_reward == 700, 'mummy xp should be 700');
        assert(stats.cr_x4 == 12, 'mummy cr_x4 should be 12');
        assert(stats.special_save_dc == 12, 'mummy special dc = 12');
    }

    #[test]
    fn test_wraith_stats() {
        let stats = MonsterType::Wraith.get_stats();
        assert(stats.ac == 13, 'wraith ac should be 13');
        assert(stats.hp == 67, 'wraith hp should be 67');
        assert(stats.attack_bonus == 6, 'wraith atk should be +6');
        assert(stats.damage_dice_sides == 8, 'wraith dmg d8');
        assert(stats.damage_dice_count == 4, 'wraith 4d8');
        assert(stats.damage_bonus == 3, 'wraith dmg +3');
        assert(stats.xp_reward == 1800, 'wraith xp should be 1800');
        assert(stats.cr_x4 == 20, 'wraith cr_x4 should be 20');
        assert(stats.special_save_dc == 14, 'wraith special dc = 14');
    }

    #[test]
    fn test_all_monsters_have_positive_hp() {
        // Every real monster should have HP > 0
        let types = array![
            MonsterType::PoisonousSnake,
            MonsterType::Skeleton,
            MonsterType::Shadow,
            MonsterType::AnimatedArmor,
            MonsterType::Gargoyle,
            MonsterType::Mummy,
            MonsterType::Wraith,
        ];
        let mut i: u32 = 0;
        while i < types.len() {
            let stats = (*types.at(i)).get_stats();
            assert(stats.hp > 0, 'monster should have hp > 0');
            assert(stats.xp_reward > 0, 'monster should give xp');
            i += 1;
        };
    }
}
