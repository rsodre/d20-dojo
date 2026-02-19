use d20::types::index::Skill;
use d20::types::items::{ArmorType, WeaponType};
use d20::models::explorer::SkillsSet;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ExplorerClass {
    #[default]
    None,
    Fighter,
    Rogue,
    Wizard,
}

#[generate_trait]
pub impl ExplorerClassImpl of ExplorerClassTrait {
    fn hit_die_max(self: ExplorerClass) -> u8 {
        match self {
            ExplorerClass::Fighter => 10,
            ExplorerClass::Rogue => 8,
            ExplorerClass::Wizard => 6,
            ExplorerClass::None => 6,
        }
    }

    fn spell_slots_for(self: ExplorerClass, level: u8) -> (u8, u8, u8) {
        match self {
            ExplorerClass::Wizard => {
                if level >= 5 {
                    (4, 3, 2)
                } else if level >= 4 {
                    (4, 3, 0)
                } else if level >= 3 {
                    (4, 2, 0)
                } else if level >= 2 {
                    (3, 0, 0)
                } else {
                    (2, 0, 0)
                }
            },
            _ => (0, 0, 0),
        }
    }

    fn build_skills(
        self: ExplorerClass, skill_choices: Span<Skill>
    ) -> SkillsSet {
        let mut result: SkillsSet = Default::default();

        match self {
            ExplorerClass::Fighter => {
                result.athletics = true;
            },
            ExplorerClass::Rogue => {
                result.stealth = true;
                result.acrobatics = true;
            },
            ExplorerClass::Wizard => {
                result.arcana = true;
            },
            ExplorerClass::None => {},
        }

        let mut i: u32 = 0;
        while i < skill_choices.len() {
            let skill = *skill_choices.at(i);
            match skill {
                Skill::Athletics => {
                    result.athletics = true;
                },
                Skill::Stealth => {
                    result.stealth = true;
                },
                Skill::Perception => {
                    result.perception = true;
                },
                Skill::Persuasion => {
                    result.persuasion = true;
                },
                Skill::Arcana => {
                    result.arcana = true;
                },
                Skill::Acrobatics => {
                    result.acrobatics = true;
                },
                Skill::None => {},
            }
            i += 1;
        };

        result
    }

    fn validate_skill_choices(self: ExplorerClass, skill_choices: Span<Skill>) {
        match self {
            ExplorerClass::Fighter => {
                assert(skill_choices.len() == 1, 'fighter needs 1 skill choice');
                let s = *skill_choices.at(0);
                assert(
                    s == Skill::Perception || s == Skill::Acrobatics, 'invalid fighter skill choice'
                );
            },
            ExplorerClass::Rogue => {
                assert(skill_choices.len() == 2, 'rogue needs 2 skill choices');
                let mut i: u32 = 0;
                while i < skill_choices.len() {
                    let s = *skill_choices.at(i);
                    assert(
                        s == Skill::Perception
                            || s == Skill::Persuasion
                            || s == Skill::Athletics
                            || s == Skill::Arcana,
                        'invalid rogue skill choice'
                    );
                    i += 1;
                };
                assert(*skill_choices.at(0) != *skill_choices.at(1), 'duplicate skill choice');
            },
            ExplorerClass::Wizard => {
                assert(skill_choices.len() == 1, 'wizard needs 1 skill choice');
                let s = *skill_choices.at(0);
                assert(
                    s == Skill::Perception || s == Skill::Persuasion, 'invalid wizard skill choice'
                );
            },
            ExplorerClass::None => {},
        }
    }

    fn validate_expertise(
        self: ExplorerClass, expertise_choices: Span<Skill>, skill_choices: Span<Skill>
    ) {
        match self {
            ExplorerClass::Rogue => {
                assert(expertise_choices.len() == 2, 'rogue needs 2 expertise');
                let mut i: u32 = 0;
                while i < expertise_choices.len() {
                    let e = *expertise_choices.at(i);
                    assert(e != Skill::None, 'expertise cannot be None');
                    let is_auto = e == Skill::Stealth || e == Skill::Acrobatics;
                    let is_chosen = skill_choices.len() >= 1
                        && (*skill_choices.at(0) == e
                            || (skill_choices.len() >= 2 && *skill_choices.at(1) == e));
                    assert(is_auto || is_chosen, 'expertise not in proficiencies');
                    i += 1;
                };
                assert(
                    *expertise_choices.at(0) != *expertise_choices.at(1),
                    'duplicate expertise choice'
                );
            },
            _ => {
                assert(expertise_choices.len() == 0, 'only rogue gets expertise');
            },
        }
    }

    fn starting_equipment(self: ExplorerClass) -> (WeaponType, WeaponType, ArmorType, bool) {
        match self {
            ExplorerClass::Fighter => {
                (WeaponType::Longsword, WeaponType::None, ArmorType::ChainMail, false)
            },
            ExplorerClass::Rogue => {
                (WeaponType::Dagger, WeaponType::Shortbow, ArmorType::Leather, false)
            },
            ExplorerClass::Wizard => {
                (WeaponType::Staff, WeaponType::None, ArmorType::None, false)
            },
            ExplorerClass::None => {
                (WeaponType::None, WeaponType::None, ArmorType::None, false)
            },
        }
    }

    fn sneak_attack_dice(self: ExplorerClass, level: u8) -> u8 {
        match self {
            ExplorerClass::Rogue => {
                if level >= 5 {
                    3
                } else if level >= 3 {
                    2
                } else {
                    1
                }
            },
            _ => 0,
        }
    }

    /// Returns the preferred stat assignment order for a class as indices into
    /// the standard array sorted descending [15, 14, 13, 12, 10, 8].
    /// Index 0 = 15 (highest), index 5 = 8 (lowest).
    /// Returns [STR_idx, DEX_idx, CON_idx, INT_idx, WIS_idx, CHA_idx].
    ///
    /// Fighter  : STR high, CON second, DEX third → STR=15, CON=14, DEX=13, WIS=12, INT=10, CHA=8
    /// Rogue    : DEX high, CON second, CHA third → DEX=15, CON=14, CHA=13, WIS=12, STR=10, INT=8
    /// Wizard   : INT high, WIS second, DEX third → INT=15, WIS=14, DEX=13, CON=12, CHA=10, STR=8
    fn preferred_stat_order(self: ExplorerClass) -> Span<u8> {
        match self {
            // [STR, DEX, CON, INT, WIS, CHA] index into sorted array
            ExplorerClass::Fighter => array![0_u8, 2_u8, 1_u8, 4_u8, 3_u8, 5_u8].span(),
            ExplorerClass::Rogue   => array![1_u8, 2_u8, 5_u8, 4_u8, 0_u8, 3_u8].span(),
            ExplorerClass::Wizard  => array![3_u8, 4_u8, 2_u8, 1_u8, 5_u8, 0_u8].span(),
            ExplorerClass::None    => array![0_u8, 1_u8, 2_u8, 3_u8, 4_u8, 5_u8].span(),
        }
    }

    /// Pick a random skill choice for a Fighter using a random byte.
    /// Fighter optional skill: Perception (0) or Acrobatics (1).
    fn random_fighter_skill(rand: u8) -> Skill {
        if rand % 2 == 0 { Skill::Perception } else { Skill::Acrobatics }
    }

    /// Pick 2 random non-duplicate skills for a Rogue using two random bytes.
    /// Rogue optional skills pool: [Perception, Persuasion, Athletics, Arcana]
    fn random_rogue_skills(rand0: u8, rand1: u8) -> (Skill, Skill) {
        let pool: [Skill; 4] = [Skill::Perception, Skill::Persuasion, Skill::Athletics, Skill::Arcana];
        let i0 = (rand0 % 4).into();
        let skill0 = *pool.span().at(i0);
        // pick a different index
        let i1_raw = rand1 % 3;
        let i1: u32 = if i1_raw >= i0.try_into().unwrap() { (i1_raw + 1).into() } else { i1_raw.into() };
        let skill1 = *pool.span().at(i1);
        (skill0, skill1)
    }

    /// Pick 2 random non-duplicate expertise skills for a Rogue.
    /// Rogue has proficiency in: Stealth, Acrobatics (auto) + the 2 chosen skills.
    /// expertise_pool = [Stealth, Acrobatics, skill0, skill1]
    fn random_rogue_expertise(rand0: u8, rand1: u8, skill0: Skill, skill1: Skill) -> (Skill, Skill) {
        let pool: [Skill; 4] = [Skill::Stealth, Skill::Acrobatics, skill0, skill1];
        let i0 = (rand0 % 4).into();
        let exp0 = *pool.span().at(i0);
        let i1_raw = rand1 % 3;
        let i1: u32 = if i1_raw >= i0.try_into().unwrap() { (i1_raw + 1).into() } else { i1_raw.into() };
        let exp1 = *pool.span().at(i1);
        (exp0, exp1)
    }

    /// Pick a random skill choice for a Wizard using a random byte.
    /// Wizard optional skill: Perception (0) or Persuasion (1).
    fn random_wizard_skill(rand: u8) -> Skill {
        if rand % 2 == 0 { Skill::Perception } else { Skill::Persuasion }
    }
}
