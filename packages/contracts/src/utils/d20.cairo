use d20::utils::seeder::{Seeder, SeederTrait};
use d20::types::ArmorType;

// ---------------------------------------------------------------------------
// VRF-based dice rolling
// ---------------------------------------------------------------------------

/// Roll a d20 (1-20) using a Seeder.
pub fn roll_d20(ref seeder: Seeder) -> u8 {
    let random_u8 = seeder.random_u8();
    ((random_u8 % 20) + 1)
}

/// Roll `count` dice each with `sides` faces (e.g. roll_dice(seeder, 6, 2) = 2d6).
/// Returns the sum of all dice.
pub fn roll_dice(ref seeder: Seeder, sides: u8, count: u8) -> u16 {
    let mut total: u16 = 0;
    let mut i: u8 = 0;
    while i < count {
        let random_u8 = seeder.random_u8();
        total += ((random_u8 % sides) + 1).into();
        i += 1;
    };
    total
}

// ---------------------------------------------------------------------------
// Pure D20 math (no world/VRF access needed)
// ---------------------------------------------------------------------------

/// D20 ability modifier: floor((score - 10) / 2).
/// Always rounds DOWN (floor division), matching the SRD.
///
/// Examples:
///   score  7 → -2
///   score  8 → -1
///   score  9 → -1
///   score 10 →  0
///   score 11 →  0
///   score 12 → +1
///   score 15 → +2
///   score 20 → +5
pub fn ability_modifier(score: u8) -> i8 {
    if score >= 10 {
        ((score - 10) / 2).try_into().unwrap()
    } else {
        -(((11 - score) / 2).try_into().unwrap())
    }
}

/// Proficiency bonus by level (D20 SRD table).
/// Levels 1-4: +2, Level 5: +3.
/// Returns +2 for any level outside 1-5 as a safe default.
pub fn proficiency_bonus(level: u8) -> u8 {
    if level >= 5 {
        3
    } else {
        2
    }
}

/// Calculate Armor Class from armor type, shield, and DEX modifier.
///
/// - No armor:   10 + DEX mod
/// - Leather:    11 + DEX mod
/// - Chain Mail: 16 (no DEX bonus)
/// - Shield adds +2 to any of the above
pub fn calculate_ac(armor: ArmorType, has_shield: bool, dex_mod: i8) -> u8 {
    let base_ac: i16 = match armor {
        ArmorType::None => 10_i16 + dex_mod.into(),
        ArmorType::Leather => 11_i16 + dex_mod.into(),
        ArmorType::ChainMail => 16_i16,
    };

    let shield_bonus: i16 = if has_shield {
        2
    } else {
        0
    };

    let total: i16 = base_ac + shield_bonus;

    // AC should never be below 0, clamp to minimum of 1
    if total < 1 {
        1
    } else {
        total.try_into().unwrap()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::{ability_modifier, proficiency_bonus, calculate_ac};
    use d20::types::ArmorType;

    // ── ability_modifier tests ──

    #[test]
    fn test_modifier_score_3() {
        assert(ability_modifier(3) == -4, 'score 3 should be -4');
    }

    #[test]
    fn test_modifier_score_4() {
        assert(ability_modifier(4) == -3, 'score 4 should be -3');
    }

    #[test]
    fn test_modifier_score_5() {
        assert(ability_modifier(5) == -3, 'score 5 should be -3');
    }

    #[test]
    fn test_modifier_score_6() {
        assert(ability_modifier(6) == -2, 'score 6 should be -2');
    }

    #[test]
    fn test_modifier_score_7() {
        assert(ability_modifier(7) == -2, 'score 7 should be -2');
    }

    #[test]
    fn test_modifier_score_8() {
        assert(ability_modifier(8) == -1, 'score 8 should be -1');
    }

    #[test]
    fn test_modifier_score_9() {
        assert(ability_modifier(9) == -1, 'score 9 should be -1');
    }

    #[test]
    fn test_modifier_score_10() {
        assert(ability_modifier(10) == 0, 'score 10 should be 0');
    }

    #[test]
    fn test_modifier_score_11() {
        assert(ability_modifier(11) == 0, 'score 11 should be 0');
    }

    #[test]
    fn test_modifier_score_12() {
        assert(ability_modifier(12) == 1, 'score 12 should be +1');
    }

    #[test]
    fn test_modifier_score_13() {
        assert(ability_modifier(13) == 1, 'score 13 should be +1');
    }

    #[test]
    fn test_modifier_score_14() {
        assert(ability_modifier(14) == 2, 'score 14 should be +2');
    }

    #[test]
    fn test_modifier_score_15() {
        assert(ability_modifier(15) == 2, 'score 15 should be +2');
    }

    #[test]
    fn test_modifier_score_16() {
        assert(ability_modifier(16) == 3, 'score 16 should be +3');
    }

    #[test]
    fn test_modifier_score_17() {
        assert(ability_modifier(17) == 3, 'score 17 should be +3');
    }

    #[test]
    fn test_modifier_score_18() {
        assert(ability_modifier(18) == 4, 'score 18 should be +4');
    }

    #[test]
    fn test_modifier_score_19() {
        assert(ability_modifier(19) == 4, 'score 19 should be +4');
    }

    #[test]
    fn test_modifier_score_20() {
        assert(ability_modifier(20) == 5, 'score 20 should be +5');
    }

    // ── proficiency_bonus tests ──

    #[test]
    fn test_proficiency_level_1() {
        assert(proficiency_bonus(1) == 2, 'level 1 should be +2');
    }

    #[test]
    fn test_proficiency_level_2() {
        assert(proficiency_bonus(2) == 2, 'level 2 should be +2');
    }

    #[test]
    fn test_proficiency_level_3() {
        assert(proficiency_bonus(3) == 2, 'level 3 should be +2');
    }

    #[test]
    fn test_proficiency_level_4() {
        assert(proficiency_bonus(4) == 2, 'level 4 should be +2');
    }

    #[test]
    fn test_proficiency_level_5() {
        assert(proficiency_bonus(5) == 3, 'level 5 should be +3');
    }

    // ── calculate_ac tests ──

    #[test]
    fn test_ac_no_armor_dex_0() {
        assert(calculate_ac(ArmorType::None, false, 0) == 10, 'no armor dex0 = 10');
    }

    #[test]
    fn test_ac_no_armor_dex_2() {
        assert(calculate_ac(ArmorType::None, false, 2) == 12, 'no armor dex2 = 12');
    }

    #[test]
    fn test_ac_no_armor_dex_neg1() {
        assert(calculate_ac(ArmorType::None, false, -1) == 9, 'no armor dex-1 = 9');
    }

    #[test]
    fn test_ac_leather_dex_2() {
        assert(calculate_ac(ArmorType::Leather, false, 2) == 13, 'leather dex2 = 13');
    }

    #[test]
    fn test_ac_leather_dex_3_shield() {
        assert(calculate_ac(ArmorType::Leather, true, 3) == 16, 'leather dex3 shield = 16');
    }

    #[test]
    fn test_ac_chain_mail() {
        assert(calculate_ac(ArmorType::ChainMail, false, 0) == 16, 'chain mail = 16');
    }

    #[test]
    fn test_ac_chain_mail_ignores_dex() {
        assert(calculate_ac(ArmorType::ChainMail, false, 3) == 16, 'chain mail ignores dex');
    }

    #[test]
    fn test_ac_chain_mail_shield() {
        assert(calculate_ac(ArmorType::ChainMail, true, 0) == 18, 'chain mail shield = 18');
    }

    #[test]
    fn test_ac_no_armor_shield() {
        assert(calculate_ac(ArmorType::None, true, 0) == 12, 'no armor shield = 12');
    }
}
