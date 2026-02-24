
#[starknet::component]
pub mod CombatComponent {
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    use d20::d20::types::combat::CombatAction;
    use d20::d20::types::items::{WeaponTypeTrait, ItemType, ItemTypeTrait};
    use d20::d20::types::spells::{SpellId, SpellIdTrait};
    use d20::d20::types::character_class::{CharacterClass, CharacterClassTrait};
    use d20::d20::models::character::{
        CharacterStats, CharacterCombat, CharacterInventory, CharacterPosition,
    };
    use d20::d20::models::dungeon::{MonsterInstance, CharacterDungeonProgress, DungeonState};
    use d20::d20::models::events::{CombatResult, LevelUp, BossDefeated};
    use d20::utils::dice::{roll_d20, roll_dice, ability_modifier, proficiency_bonus};
    use d20::utils::seeder::Seeder;
    use d20::d20::models::monster::{MonsterType, MonsterTypeTrait};
    use d20::d20::types::damage::DamageTrait;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn attack(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class != CharacterClass::None, 'character does not exist');
            assert(!stats.is_dead, 'dead character cannot act');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.in_combat, 'not in combat');

            let inventory: CharacterInventory = world.read_model(character_id);
            let combat: CharacterCombat = world.read_model(character_id);

            let monster: MonsterInstance = world.read_model(
                (position.dungeon_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster is already dead');

            let monster_stats = monster.monster_type.get_stats();

            // Fighter level 5+: Extra Attack
            let num_attacks: u8 = if stats.character_class == CharacterClass::Fighter
                && stats.level >= 5 {
                2
            } else {
                1
            };

            let weapon = inventory.primary_weapon;
            let uses_dex = weapon.uses_dex();
            let ability_score: u8 = if uses_dex {
                stats.abilities.dexterity
            } else {
                stats.abilities.strength
            };
            let ability_mod: i8 = ability_modifier(ability_score);
            let prof_bonus: u8 = proficiency_bonus(stats.level);

            // Fighter Champion: crit on 19-20 at level 3+
            let crit_threshold: u8 = if stats.character_class == CharacterClass::Fighter
                && stats.level >= 3 {
                19
            } else {
                20
            };

            let mut total_damage_dealt: u16 = 0;
            let mut monster_current_hp = monster.current_hp;
            let mut monster_killed: bool = false;
            let mut first_attack_roll: u8 = 0;

            let mut atk_num: u8 = 0;
            while atk_num < num_attacks && !monster_killed {
                let attack_roll: u8 = roll_d20(ref seeder);
                if atk_num == 0 {
                    first_attack_roll = attack_roll;
                }

                let is_nat_1: bool = attack_roll == 1;
                let is_crit: bool = attack_roll >= crit_threshold;
                let total_attack: i16 = attack_roll.into() + ability_mod.into() + prof_bonus.into();
                let hits: bool = !is_nat_1 && (is_crit || total_attack >= monster_stats.ac.into());

                if hits {
                    let dice_sides: u8 = weapon.damage_sides();
                    let base_count: u8 = weapon.damage_count();
                    let dice_count: u8 = if is_crit { base_count * 2 } else { base_count };
                    let raw_damage: u16 = roll_dice(ref seeder, dice_sides, dice_count);

                    // Rogue: Sneak Attack
                    let sneak_bonus: u16 = if stats.character_class == CharacterClass::Rogue {
                        let sneak_dice: u8 = stats.character_class.sneak_attack_dice(stats.level);
                        let sneak_count: u8 = if is_crit { sneak_dice * 2 } else { sneak_dice };
                        roll_dice(ref seeder, 6, sneak_count)
                    } else {
                        0
                    };

                    let raw_dmg_i32: i32 = raw_damage.into();
                    let sneak_i32: i32 = sneak_bonus.into();
                    let mod_i32: i32 = ability_mod.into();
                    let damage_i32: i32 = raw_dmg_i32 + sneak_i32 + mod_i32;
                    let damage_with_mod: i16 = damage_i32.try_into().unwrap();
                    let attack_damage: u16 = if damage_with_mod < 1 {
                        1
                    } else {
                        damage_with_mod.try_into().unwrap()
                    };

                    total_damage_dealt += attack_damage;
                    monster_current_hp -= attack_damage.try_into().unwrap();
                    if monster_current_hp <= 0 {
                        monster_killed = true;
                    }
                }

                atk_num += 1;
            };

            // Write final monster state
            if monster_killed {
                world.write_model(@MonsterInstance {
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    monster_id: position.combat_monster_id,
                    monster_type: monster.monster_type,
                    current_hp: monster_current_hp,
                    max_hp: monster.max_hp,
                    is_alive: false,
                });
                world.write_model(@CharacterPosition {
                    character_id,
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    in_combat: false,
                    combat_monster_id: 0,
                });
                // Award XP for the kill
                gain_xp(ref world, ref seeder, character_id, position.dungeon_id, monster_stats.xp_reward);
                // Check for boss defeat
                check_boss_defeat(
                    ref world, character_id, position.dungeon_id,
                    position.chamber_id, monster.monster_type,
                );
            } else {
                world.write_model(@MonsterInstance {
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    monster_id: position.combat_monster_id,
                    monster_type: monster.monster_type,
                    current_hp: monster_current_hp,
                    max_hp: monster.max_hp,
                    is_alive: true,
                });
            }

            // Monster counter-attack
            let mut damage_taken: u16 = 0;
            if !monster_killed {
                let updated_stats: CharacterStats = world.read_model(character_id);
                if !updated_stats.is_dead {
                    let updated_monster = MonsterInstance {
                        dungeon_id: position.dungeon_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: monster_current_hp,
                        max_hp: monster.max_hp,
                        is_alive: true,
                    };
                    let (dmg, _died) = monster_turn(
                        ref world, ref seeder, character_id, updated_stats,
                        combat, position, updated_monster,
                    );
                    damage_taken = dmg;
                }
            }

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::Attack,
                roll: first_attack_roll,
                damage_dealt: total_damage_dealt,
                damage_taken,
                monster_killed,
            });
        }

        fn cast_spell(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            spell_id: SpellId,
            ref seeder: Seeder,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class == CharacterClass::Wizard, 'only wizards cast spells');
            assert(stats.character_class != CharacterClass::None, 'character does not exist');
            assert(!stats.is_dead, 'dead character cannot act');

            let position: CharacterPosition = world.read_model(character_id);

            // Consume spell slot if leveled
            let slot_level: u8 = spell_id.level();
            if slot_level > 0 {
                assert(position.in_combat || slot_level == 1, 'must be in combat');
                consume_spell_slot(ref world, character_id, slot_level);
            }

            // INT modifier for spell attack rolls and save DCs
            let int_mod: i8 = ability_modifier(stats.abilities.intelligence);
            let prof_bonus: u8 = proficiency_bonus(stats.level);

            let (damage_dealt, monster_killed, spell_roll, xp_to_award) = spell_id
                .resolve(ref world, ref seeder, character_id, position, int_mod, prof_bonus);

            // Award XP and check for boss defeat on kill
            if monster_killed && xp_to_award > 0 {
                gain_xp(ref world, ref seeder, character_id, position.dungeon_id, xp_to_award);
            }
            if monster_killed {
                // Re-read the monster type from the MonsterInstance (xp_to_award==0 for
                // MistyStep/Shield which never kill, so this only fires on real kills)
                let killed_monster: MonsterInstance = world.read_model(
                    (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                );
                check_boss_defeat(
                    ref world, character_id, position.dungeon_id,
                    position.chamber_id, killed_monster.monster_type,
                );
            }

            // ── Monster counter-attack (unless killed or disengaged) ──────────
            // Shield and MistyStep don't kill the monster; Shield stays in combat,
            // MistyStep disengages. Only counter-attack when still in_combat.
            let mut damage_taken: u16 = 0;
            if !monster_killed {
                // Re-read position — MistyStep may have cleared in_combat
                let updated_position: CharacterPosition = world.read_model(character_id);
                if updated_position.in_combat {
                    let updated_stats: CharacterStats = world.read_model(character_id);
                    if !updated_stats.is_dead {
                        let updated_combat: CharacterCombat = world.read_model(character_id);
                        let live_monster: MonsterInstance = world.read_model(
                            (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                        );
                        let (dmg, _died) = monster_turn(
                            ref world, ref seeder, character_id, updated_stats,
                            updated_combat, updated_position, live_monster,
                        );
                        damage_taken = dmg;
                    }
                }
            }

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::CastSpell,
                roll: spell_roll,
                damage_dealt,
                damage_taken,
                monster_killed,
            });
        }

        /// Use a consumable item. Currently: HealthPotion (2d4+2 heal).
        fn use_item(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            item_type: ItemType,
            ref seeder: Seeder,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class != CharacterClass::None, 'character does not exist');
            assert(!stats.is_dead, 'dead character cannot act');

            let roll: u8 = item_type.resolve(ref world, ref seeder, character_id, stats);

            // Monster counter-attacks after using item (if in combat)
            let position: CharacterPosition = world.read_model(character_id);
            let mut damage_taken: u16 = 0;
            if position.in_combat {
                let updated_stats: CharacterStats = world.read_model(character_id);
                let combat: CharacterCombat = world.read_model(character_id);
                let monster: MonsterInstance = world.read_model(
                    (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                );
                if monster.is_alive {
                    let (dmg, _died) = monster_turn(
                        ref world, ref seeder, character_id, updated_stats,
                        combat, position, monster,
                    );
                    damage_taken = dmg;
                }
            }

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::UseItem,
                roll,
                damage_dealt: 0,
                damage_taken,
                monster_killed: false,
            });
        }

        /// Fighter: heal 1d10 + level once per rest.
        fn second_wind(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class == CharacterClass::Fighter, 'only fighters can second wind');
            assert(!stats.is_dead, 'dead character cannot act');

            let mut combat: CharacterCombat = world.read_model(character_id);
            assert(!combat.second_wind_used, 'second wind already used');

            let heal_roll: u16 = roll_dice(ref seeder, 10, 1);
            let heal_total: u16 = heal_roll + stats.level.into();

            let new_hp_i16: i16 = stats.current_hp + heal_total.try_into().unwrap();
            let new_hp: i16 = if new_hp_i16 > stats.max_hp.try_into().unwrap() {
                stats.max_hp.try_into().unwrap()
            } else {
                new_hp_i16
            };

            let mut healed_stats = stats;
            healed_stats.current_hp = new_hp;
            healed_stats.is_dead = false;
            world.write_model(@healed_stats);

            combat.second_wind_used = true;
            world.write_model(@combat);

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::SecondWind,
                roll: heal_roll.try_into().unwrap(),
                damage_dealt: 0,
                damage_taken: 0,
                monster_killed: false,
            });
        }

        /// Rogue: disengage from combat without triggering monster counter-attack.
        fn cunning_action(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class == CharacterClass::Rogue, 'only rogues can cunning action');
            assert(stats.level >= 2, 'cunning action needs level 2');
            assert(!stats.is_dead, 'dead character cannot act');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.in_combat, 'not in combat');

            world.write_model(@CharacterPosition {
                character_id,
                dungeon_id: position.dungeon_id,
                chamber_id: position.chamber_id,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::CunningAction,
                roll: 0,
                damage_dealt: 0,
                damage_taken: 0,
                monster_killed: false,
            });
        }

        /// Contested DEX check: roll d20 + character DEX mod vs roll d20 + monster DEX mod.
        /// On success: character disengages (clears in_combat) — no counter-attack.
        /// On failure: monster gets a free counter-attack.
        fn flee(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: CharacterStats = world.read_model(character_id);
            assert(stats.character_class != CharacterClass::None, 'character does not exist');
            assert(!stats.is_dead, 'dead character cannot act');

            let mut position: CharacterPosition = world.read_model(character_id);
            assert(position.in_combat, 'not in combat');

            let monster: MonsterInstance = world.read_model(
                (position.dungeon_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster already dead');

            // Character DEX roll: d20 + DEX modifier
            let character_roll: u8 = roll_d20(ref seeder);
            let character_dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
            let character_dex_mod_i32: i32 = character_dex_mod.into();
            let character_roll_i32: i32 = character_roll.into();
            let character_total: i32 = character_roll_i32 + character_dex_mod_i32;

            // Monster DEX roll: d20 + monster DEX modifier
            let monster_stats = monster.monster_type.get_stats();
            let monster_roll: u8 = roll_d20(ref seeder);
            let monster_dex_mod: i8 = ability_modifier(monster_stats.dexterity);
            let monster_dex_mod_i32: i32 = monster_dex_mod.into();
            let monster_roll_i32: i32 = monster_roll.into();
            let monster_total: i32 = monster_roll_i32 + monster_dex_mod_i32;

            // character wins ties (they initiated the flee)
            let flee_success = character_total >= monster_total;

            let mut damage_taken: u16 = 0;

            if flee_success {
                // Clear combat — character disengages
                world.write_model(@CharacterPosition {
                    character_id,
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    in_combat: false,
                    combat_monster_id: 0,
                });
            } else {
                // Monster gets a free counter-attack on failed flee
                let combat: CharacterCombat = world.read_model(character_id);
                let (dmg, _died) = monster_turn(
                    ref world, ref seeder, character_id, stats, combat, position, monster,
                );
                damage_taken = dmg;
            }

            world.emit_event(@CombatResult {
                character_id,
                action: CombatAction::Flee,
                roll: character_roll,
                damage_dealt: 0,
                damage_taken,
                monster_killed: false,
            });
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /// Execute the monster's counter-attack against the character.
    /// Returns (damage_taken, character_died).
    fn monster_turn(
        ref world: WorldStorage,
        ref seeder: Seeder,
        character_id: u128,
        stats: CharacterStats,
        combat: CharacterCombat,
        position: CharacterPosition,
        monster: MonsterInstance,
    ) -> (u16, bool) {
        let monster_stats = monster.monster_type.get_stats();

        let mut total_damage: u16 = 0;
        let mut character_died: bool = false;
        let mut current_stats = stats;

        let mut attack_num: u8 = 0;
        while attack_num < monster_stats.num_attacks && !character_died {
            let monster_roll: u8 = roll_d20(ref seeder);
            let is_nat_1: bool = monster_roll == 1;
            let is_nat_20: bool = monster_roll == 20;

            let monster_atk_total: i16 = monster_roll.into() + monster_stats.attack_bonus.into();

            let monster_hits: bool = !is_nat_1
                && (is_nat_20 || monster_atk_total >= combat.armor_class.into());

            if monster_hits {
                let dice_count: u8 = if is_nat_20 {
                    monster_stats.damage_dice_count * 2
                } else {
                    monster_stats.damage_dice_count
                };

                let raw_dmg: u16 = roll_dice(ref seeder, monster_stats.damage_dice_sides, dice_count);
                let raw_dmg_i32: i32 = raw_dmg.into();
                let bonus_i32: i32 = monster_stats.damage_bonus.into();
                let dmg_i32: i32 = raw_dmg_i32 + bonus_i32;
                let dmg_with_bonus: i16 = dmg_i32.try_into().unwrap();
                let monster_damage: u16 = if dmg_with_bonus < 1 {
                    1
                } else {
                    dmg_with_bonus.try_into().unwrap()
                };

                let damage_i16: i16 = monster_damage.try_into().unwrap();
                let new_hp: i16 = current_stats.current_hp - damage_i16;

                let damage_taken = DamageTrait::apply_character_damage(
                    ref world,
                    character_id,
                    current_stats,
                    position,
                    monster.monster_type,
                    monster_damage,
                );

                total_damage += damage_taken;

                if new_hp <= 0 {
                    character_died = true;
                } else {
                    current_stats.current_hp = new_hp;
                    current_stats.is_dead = false;
                }
            }

            attack_num += 1;
        };

        (total_damage, character_died)
    }

    /// Returns the XP required for the given level (1-5).
    /// Level 1 = 0, 2 = 300, 3 = 900, 4 = 2700, 5 = 6500.
    fn xp_threshold(level: u8) -> u32 {
        if level <= 1 { 0 }
        else if level == 2 { 300 }
        else if level == 3 { 900 }
        else if level == 4 { 2700 }
        else { 6500 }
    }

    /// Apply a level-up: increment level, roll HP, update spell slots, emit event.
    fn level_up(
        ref world: WorldStorage,
        ref seeder: Seeder,
        character_id: u128,
        stats: CharacterStats,
    ) {
        let new_level: u8 = stats.level + 1;

        // Roll hit die + CON modifier, minimum 1, add to max HP
        let hit_sides: u8 = stats.character_class.hit_die_max();
        let raw_roll: u16 = roll_dice(ref seeder, hit_sides, 1);
        let con_mod: i8 = ability_modifier(stats.abilities.constitution);
        let raw_roll_i32: i32 = raw_roll.into();
        let con_mod_i32: i32 = con_mod.into();
        let hp_gain_i32: i32 = raw_roll_i32 + con_mod_i32;
        let hp_gain: u16 = if hp_gain_i32 < 1 { 1 } else { hp_gain_i32.try_into().unwrap() };
        let new_max_hp: u16 = stats.max_hp + hp_gain;

        // Update level and max HP in CharacterStats
        world.write_model(@CharacterStats {
            character_id,
            abilities: stats.abilities,
            level: new_level,
            xp: stats.xp,
            character_class: stats.character_class,
            dungeons_conquered: stats.dungeons_conquered,
            current_hp: stats.current_hp,
            max_hp: new_max_hp,
            is_dead: stats.is_dead,
        });

        // Update spell slots for Wizards
        if stats.character_class == CharacterClass::Wizard {
            let combat: CharacterCombat = world.read_model(character_id);
            let (slots_1, slots_2, slots_3) = stats.character_class.spell_slots_for(new_level);
            world.write_model(@CharacterCombat {
                character_id,
                armor_class: combat.armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: combat.second_wind_used,
                action_surge_used: combat.action_surge_used,
            });
        }

        world.emit_event(@LevelUp { character_id, new_level });
    }

    /// Award XP to the character for killing a monster.
    /// Updates CharacterStats.xp and CharacterDungeonProgress.xp_earned.
    /// Triggers level_up if an XP threshold is crossed (max level 5).
    fn gain_xp(
        ref world: WorldStorage,
        ref seeder: Seeder,
        character_id: u128,
        dungeon_id: u128,
        xp_reward: u32,
    ) {
        let mut stats: CharacterStats = world.read_model(character_id);

        // Don't grant XP beyond level 5
        if stats.level >= 5 {
            return;
        }

        let new_xp: u32 = stats.xp + xp_reward;
        stats.xp = new_xp;
        world.write_model(@stats);

        // Update dungeon progress XP
        if dungeon_id != 0 {
            let mut progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));
            world.write_model(@CharacterDungeonProgress {
                character_id,
                dungeon_id,
                chambers_explored: progress.chambers_explored,
                xp_earned: progress.xp_earned + xp_reward,
            });
        }

        // Check for level-up (level 2-5 thresholds)
        let mut current_level: u8 = stats.level;
        while current_level < 5 {
            let next_threshold: u32 = xp_threshold(current_level + 1);
            if new_xp >= next_threshold {
                // Re-read stats in case level already updated
                let current_stats: CharacterStats = world.read_model(character_id);
                level_up(ref world, ref seeder, character_id, current_stats);
                current_level += 1;
            } else {
                break;
            }
        };
    }

    /// Check if the just-killed monster was the boss. If so:
    ///   1. Mark DungeonState.boss_alive = false.
    ///   2. Increment CharacterStats.dungeons_conquered.
    ///   3. Emit BossDefeated event.
    fn check_boss_defeat(
        ref world: WorldStorage,
        character_id: u128,
        dungeon_id: u128,
        chamber_id: u32,
        monster_type: MonsterType,
    ) {
        if dungeon_id == 0 {
            return;
        }
        let mut dungeon: DungeonState = world.read_model(dungeon_id);
        if !dungeon.boss_alive {
            return; // already defeated
        }
        if chamber_id != dungeon.boss_chamber_id {
            return; // not the boss chamber
        }
        // Mark dungeon boss as defeated
        dungeon.boss_alive = false;
        world.write_model(@dungeon);

        // Increment dungeons_conquered on the character
        let mut stats: CharacterStats = world.read_model(character_id);
        stats.dungeons_conquered += 1;
        world.write_model(@stats);

        // Emit BossDefeated event
        world.emit_event(@BossDefeated { dungeon_id, character_id, monster_type });
    }

    /// Consume a spell slot of the given level. Panics if none available.
    fn consume_spell_slot(ref world: WorldStorage, character_id: u128, level: u8) {
        let mut combat: CharacterCombat = world.read_model(character_id);
        if level == 1 {
            assert(combat.spell_slots_1 > 0, 'no 1st level slots');
            combat.spell_slots_1 -= 1;
        } else if level == 2 {
            assert(combat.spell_slots_2 > 0, 'no 2nd level slots');
            combat.spell_slots_2 -= 1;
        } else if level == 3 {
            assert(combat.spell_slots_3 > 0, 'no 3rd level slots');
            combat.spell_slots_3 -= 1;
        }
        world.write_model(@combat);
    }
}
