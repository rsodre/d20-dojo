use d20::types::index::Skill;
use d20::types::items::{ArmorType, WeaponType};

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
    ) -> (bool, bool, bool, bool, bool, bool) {
        let mut athletics: bool = false;
        let mut stealth: bool = false;
        let mut perception: bool = false;
        let mut persuasion: bool = false;
        let mut arcana: bool = false;
        let mut acrobatics: bool = false;

        match self {
            ExplorerClass::Fighter => {
                athletics = true;
            },
            ExplorerClass::Rogue => {
                stealth = true;
                acrobatics = true;
            },
            ExplorerClass::Wizard => {
                arcana = true;
            },
            ExplorerClass::None => {},
        }

        let mut i: u32 = 0;
        while i < skill_choices.len() {
            let skill = *skill_choices.at(i);
            match skill {
                Skill::Athletics => {
                    athletics = true;
                },
                Skill::Stealth => {
                    stealth = true;
                },
                Skill::Perception => {
                    perception = true;
                },
                Skill::Persuasion => {
                    persuasion = true;
                },
                Skill::Arcana => {
                    arcana = true;
                },
                Skill::Acrobatics => {
                    acrobatics = true;
                },
                Skill::None => {},
            }
            i += 1;
        };

        (athletics, stealth, perception, persuasion, arcana, acrobatics)
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
}
