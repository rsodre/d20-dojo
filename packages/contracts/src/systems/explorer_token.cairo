use d20::types::{ExplorerClass, Skill};

#[starknet::interface]
pub trait IExplorerActions<T> {
    /// Mint a new Explorer NFT.
    ///
    /// Parameters:
    /// - `class`: Fighter, Rogue, or Wizard
    /// - `stat_assignment`: 6 values assigned to [STR, DEX, CON, INT, WIS, CHA]
    ///   Must be a permutation of [15, 14, 13, 12, 10, 8] (standard array).
    /// - `skill_choices`: class-specific optional skill picks
    /// - `expertise_choices`: Rogue only — 2 skills for double proficiency (Expertise)
    ///
    /// Returns the new explorer's token ID (u128).
    fn mint_explorer(
        ref self: T,
        class: ExplorerClass,
        stat_assignment: Span<u8>,
        skill_choices: Span<Skill>,
        expertise_choices: Span<Skill>,
    ) -> u128;

    /// Restore HP to max, reset spell slots to class/level values,
    /// and reset `second_wind_used` / `action_surge_used`.
    fn rest(ref self: T, explorer_id: u128);
}

#[dojo::contract]
pub mod explorer_token {
    use super::IExplorerActions;
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use dojo::world::{WorldStorage, IWorldDispatcherTrait};

    use d20::types::{ExplorerClass, Skill, WeaponType, ArmorType};
    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills,
    };
    use d20::events::ExplorerMinted;
    use d20::utils::d20::{ability_modifier, calculate_ac};

    // ── world_default helper ────────────────────────────────────────────────

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"d20_0_1")
        }
    }

    // ── Standard array validation ───────────────────────────────────────────

    /// Validate that stat_assignment is a permutation of [15, 14, 13, 12, 10, 8].
    /// Panics if the assignment is invalid.
    fn validate_standard_array(stat_assignment: Span<u8>) {
        assert(stat_assignment.len() == 6, 'need exactly 6 stats');

        // Expected counts: 8×1, 10×1, 12×1, 13×1, 14×1, 15×1
        let mut count_8: u8 = 0;
        let mut count_10: u8 = 0;
        let mut count_12: u8 = 0;
        let mut count_13: u8 = 0;
        let mut count_14: u8 = 0;
        let mut count_15: u8 = 0;

        let mut i: u32 = 0;
        loop {
            if i >= stat_assignment.len() {
                break;
            }
            let v = *stat_assignment.at(i);
            if v == 8 {
                count_8 += 1;
            } else if v == 10 {
                count_10 += 1;
            } else if v == 12 {
                count_12 += 1;
            } else if v == 13 {
                count_13 += 1;
            } else if v == 14 {
                count_14 += 1;
            } else if v == 15 {
                count_15 += 1;
            } else {
                panic!("invalid stat value");
            }
            i += 1;
        };

        assert(
            count_8 == 1
                && count_10 == 1
                && count_12 == 1
                && count_13 == 1
                && count_14 == 1
                && count_15 == 1,
            'not standard array'
        );
    }

    // ── Spell slot initialization by class and level ────────────────────────

    fn spell_slots_for(class: ExplorerClass, level: u8) -> (u8, u8, u8) {
        match class {
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
                    (2, 0, 0) // level 1
                }
            },
            _ => (0, 0, 0), // Fighter and Rogue have no spell slots
        }
    }

    // ── Starting HP by class ────────────────────────────────────────────────

    /// Hit die maximum for each class (used for level-1 HP).
    fn hit_die_max(class: ExplorerClass) -> u8 {
        match class {
            ExplorerClass::Fighter => 10,
            ExplorerClass::Rogue => 8,
            ExplorerClass::Wizard => 6,
            ExplorerClass::None => 6,
        }
    }

    // ── Skill initialization by class and choices ───────────────────────────

    /// Build skill flags for an explorer given class and optional skill choices.
    /// Returns (athletics, stealth, perception, persuasion, arcana, acrobatics).
    fn build_skills(
        class: ExplorerClass,
        skill_choices: Span<Skill>,
    ) -> (bool, bool, bool, bool, bool, bool) {
        let mut athletics: bool = false;
        let mut stealth: bool = false;
        let mut perception: bool = false;
        let mut persuasion: bool = false;
        let mut arcana: bool = false;
        let mut acrobatics: bool = false;

        // Set automatic proficiencies by class
        match class {
            ExplorerClass::Fighter => {
                athletics = true; // Fighter: Athletics is automatic
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

        // Apply optional skill choices
        let mut i: u32 = 0;
        loop {
            if i >= skill_choices.len() {
                break;
            }
            let skill = *skill_choices.at(i);
            match skill {
                Skill::Athletics => { athletics = true; },
                Skill::Stealth => { stealth = true; },
                Skill::Perception => { perception = true; },
                Skill::Persuasion => { persuasion = true; },
                Skill::Arcana => { arcana = true; },
                Skill::Acrobatics => { acrobatics = true; },
                Skill::None => {},
            }
            i += 1;
        };

        (athletics, stealth, perception, persuasion, arcana, acrobatics)
    }

    // ── Validate expertise choices (Rogue only) ─────────────────────────────

    fn get_expertise(
        class: ExplorerClass,
        expertise_choices: Span<Skill>,
    ) -> (Skill, Skill) {
        match class {
            ExplorerClass::Rogue => {
                assert(expertise_choices.len() == 2, 'rogue needs 2 expertise');
                (*expertise_choices.at(0), *expertise_choices.at(1))
            },
            _ => (Skill::None, Skill::None),
        }
    }

    // ── Interface implementation ────────────────────────────────────────────

    #[abi(embed_v0)]
    impl ExplorerActionsImpl of IExplorerActions<ContractState> {
        fn mint_explorer(
            ref self: ContractState,
            class: ExplorerClass,
            stat_assignment: Span<u8>,
            skill_choices: Span<Skill>,
            expertise_choices: Span<Skill>,
        ) -> u128 {
            assert(class != ExplorerClass::None, 'must choose a class');

            // Validate stats
            validate_standard_array(stat_assignment);

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Mint sequential ID via world dispatcher uuid()
            let explorer_id: u128 = world.dispatcher.uuid().into();

            // Unpack stats [STR, DEX, CON, INT, WIS, CHA]
            let strength: u8 = *stat_assignment.at(0);
            let dexterity: u8 = *stat_assignment.at(1);
            let constitution: u8 = *stat_assignment.at(2);
            let intelligence: u8 = *stat_assignment.at(3);
            let wisdom: u8 = *stat_assignment.at(4);
            let charisma: u8 = *stat_assignment.at(5);

            let con_mod: i8 = ability_modifier(constitution);
            let dex_mod: i8 = ability_modifier(dexterity);

            // Starting HP: hit die max + CON modifier (minimum 1)
            let hit_die = hit_die_max(class);
            let raw_hp: i16 = hit_die.into() + con_mod.into();
            let max_hp: u16 = if raw_hp < 1 {
                1
            } else {
                raw_hp.try_into().unwrap()
            };

            // Starting equipment and AC by class
            let (primary_weapon, secondary_weapon, armor, has_shield, armor_class) = match class {
                ExplorerClass::Fighter => {
                    let ac = calculate_ac(ArmorType::ChainMail, false, dex_mod);
                    (WeaponType::Longsword, WeaponType::None, ArmorType::ChainMail, false, ac)
                },
                ExplorerClass::Rogue => {
                    let ac = calculate_ac(ArmorType::Leather, false, dex_mod);
                    (WeaponType::Dagger, WeaponType::Shortbow, ArmorType::Leather, false, ac)
                },
                ExplorerClass::Wizard => {
                    let ac = calculate_ac(ArmorType::None, false, dex_mod);
                    (WeaponType::Staff, WeaponType::None, ArmorType::None, false, ac)
                },
                ExplorerClass::None => {
                    (WeaponType::None, WeaponType::None, ArmorType::None, false, 10)
                },
            };

            // Spell slots (level 1)
            let (slots_1, slots_2, slots_3) = spell_slots_for(class, 1);

            // Skills
            let (athletics, stealth, perception, persuasion, arcana, acrobatics) =
                build_skills(class, skill_choices);

            // Expertise (Rogue only)
            let (expertise_1, expertise_2) = get_expertise(class, expertise_choices);

            // Write all explorer models
            world.write_model(@ExplorerStats {
                explorer_id,
                strength,
                dexterity,
                constitution,
                intelligence,
                wisdom,
                charisma,
                level: 1,
                xp: 0,
                class,
                temples_conquered: 0,
            });

            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: max_hp.try_into().unwrap(),
                max_hp,
                is_dead: false,
            });

            world.write_model(@ExplorerCombat {
                explorer_id,
                armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });

            world.write_model(@ExplorerInventory {
                explorer_id,
                primary_weapon,
                secondary_weapon,
                armor,
                has_shield,
                gold: 0,
                potions: 0,
            });

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.write_model(@ExplorerSkills {
                explorer_id,
                athletics,
                stealth,
                perception,
                persuasion,
                arcana,
                acrobatics,
                expertise_1,
                expertise_2,
            });

            // Emit ExplorerMinted event
            world.emit_event(@ExplorerMinted {
                explorer_id,
                class,
                player: caller,
            });

            explorer_id
        }

        fn rest(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            // Load stats to get class and level
            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.class != ExplorerClass::None, 'explorer does not exist');

            // Load health — must not be dead
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot rest');

            // Restore HP to max
            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: health.max_hp.try_into().unwrap(),
                max_hp: health.max_hp,
                is_dead: false,
            });

            // Reset spell slots to class/level values
            let (slots_1, slots_2, slots_3) = spell_slots_for(stats.class, stats.level);

            // Load and reset combat state
            let combat: ExplorerCombat = world.read_model(explorer_id);
            world.write_model(@ExplorerCombat {
                explorer_id,
                armor_class: combat.armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });
        }
    }
}
