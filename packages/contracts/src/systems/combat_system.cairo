use d20::types::SpellId;
use d20::types::ItemType;

// ── Public interface ────────────────────────────────────────────────────────

#[starknet::interface]
pub trait ICombatSystem<TState> {
    /// Attack the monster the explorer is currently in combat with.
    /// Rolls attack (d20 + STR/DEX mod + proficiency) vs monster AC.
    /// On hit, rolls weapon damage and deducts from MonsterInstance HP.
    /// Monster counter-attacks after the explorer's action (task 2.5).
    /// Emits CombatResult event.
    fn attack(ref self: TState, explorer_id: u128);

    /// Cast a spell (task 2.8 — stub for now).
    fn cast_spell(ref self: TState, explorer_id: u128, spell_id: SpellId);

    /// Use an item (task 2.8 — stub for now).
    fn use_item(ref self: TState, explorer_id: u128, item_type: ItemType);

    /// Flee from combat (task 2.10 — stub for now).
    fn flee(ref self: TState, explorer_id: u128);

    /// Fighter: heal 1d10 + level once per rest (task 2.6).
    fn second_wind(ref self: TState, explorer_id: u128);

    /// Rogue: disengage from combat without triggering monster counter-attack (task 2.7).
    fn cunning_action(ref self: TState, explorer_id: u128);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod combat_system {
    use super::ICombatSystem;
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use dojo::world::WorldStorage;

    use d20::types::{ExplorerClass, WeaponType, SpellId, ItemType, CombatAction, MonsterType};
    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory, ExplorerPosition,
    };
    use d20::models::temple::MonsterInstance;
    use d20::events::{CombatResult, ExplorerDied};
    use d20::utils::d20::{roll_d20, roll_dice, ability_modifier, proficiency_bonus};
    use d20::utils::monsters::get_monster_stats;

    // ── Storage ──────────────────────────────────────────────────────────────

    #[storage]
    struct Storage {}

    // ── Events ───────────────────────────────────────────────────────────────

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // ── Internal helpers ─────────────────────────────────────────────────────

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"d20_0_1")
        }

        /// Weapon dice sides for damage roll.
        fn weapon_damage_sides(weapon: WeaponType) -> u8 {
            match weapon {
                WeaponType::Longsword => 8,
                WeaponType::Dagger => 4,
                WeaponType::Shortbow => 6,
                WeaponType::Greataxe => 12,
                WeaponType::Staff => 6,
                WeaponType::None => 4,
            }
        }

        /// Weapon dice count for damage roll (all standard weapons: 1).
        fn weapon_damage_count(weapon: WeaponType) -> u8 {
            match weapon {
                WeaponType::None => 0,
                _ => 1,
            }
        }

        /// Whether a weapon uses DEX modifier (ranged / finesse).
        fn weapon_uses_dex(weapon: WeaponType) -> bool {
            match weapon {
                WeaponType::Dagger => true,
                WeaponType::Shortbow => true,
                _ => false,
            }
        }

        /// Apply damage to the explorer. Returns the actual damage taken.
        /// If HP drops to 0, calls handle_death.
        fn apply_explorer_damage(
            ref world: WorldStorage,
            explorer_id: u128,
            health: ExplorerHealth,
            position: ExplorerPosition,
            monster_type: MonsterType,
            damage: u16,
        ) -> u16 {
            let damage_i16: i16 = damage.try_into().unwrap();
            let new_hp: i16 = health.current_hp - damage_i16;

            if new_hp <= 0 {
                Self::handle_death(ref world, explorer_id, health, position, monster_type);
                // Return actual HP lost (was positive before)
                health.current_hp.try_into().unwrap()
            } else {
                world.write_model(@ExplorerHealth {
                    explorer_id,
                    current_hp: new_hp,
                    max_hp: health.max_hp,
                    is_dead: false,
                });
                damage
            }
        }

        /// Handle explorer death: set is_dead, clear combat, emit ExplorerDied.
        /// FallenExplorer creation and ChamberFallenCount are handled in task 2.9.
        fn handle_death(
            ref world: WorldStorage,
            explorer_id: u128,
            health: ExplorerHealth,
            position: ExplorerPosition,
            monster_type: MonsterType,
        ) {
            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: 0,
                max_hp: health.max_hp,
                is_dead: true,
            });

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: position.temple_id,
                chamber_id: position.chamber_id,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.emit_event(@ExplorerDied {
                explorer_id,
                temple_id: position.temple_id,
                chamber_id: position.chamber_id,
                killed_by: monster_type,
            });
        }

        // ── Monster turn (task 2.5) ──────────────────────────────────────────

        /// Execute the monster's counter-attack against the explorer.
        /// Returns (damage_taken, explorer_died).
        /// Only called when the monster is still alive after the explorer's action.
        fn monster_turn(
            ref world: WorldStorage,
            caller: starknet::ContractAddress,
            explorer_id: u128,
            stats: ExplorerStats,
            health: ExplorerHealth,
            combat: ExplorerCombat,
            position: ExplorerPosition,
            monster: MonsterInstance,
        ) -> (u16, bool) {
            let monster_stats = get_monster_stats(monster.monster_type);

            // Monster can make multiple attacks (multiattack)
            let mut total_damage: u16 = 0;
            let mut explorer_died: bool = false;
            let mut current_health = health;

            let mut attack_num: u8 = 0;
            loop {
                if attack_num >= monster_stats.num_attacks || explorer_died {
                    break;
                }

                let monster_roll: u8 = roll_d20(caller);
                let is_nat_1: bool = monster_roll == 1;
                let is_nat_20: bool = monster_roll == 20;

                // Monster attack total vs explorer AC
                let monster_atk_total: i16 = monster_roll.into()
                    + monster_stats.attack_bonus.into();

                let monster_hits: bool = !is_nat_1
                    && (is_nat_20 || monster_atk_total >= combat.armor_class.into());

                if monster_hits {
                    // Damage roll: monster_stats.damage_dice_count d monster_stats.damage_dice_sides
                    let dice_count: u8 = if is_nat_20 {
                        monster_stats.damage_dice_count * 2
                    } else {
                        monster_stats.damage_dice_count
                    };

                    let raw_dmg: u16 = roll_dice(
                        caller, monster_stats.damage_dice_sides, dice_count
                    );
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
                    let new_hp: i16 = current_health.current_hp - damage_i16;

                    let damage_taken = Self::apply_explorer_damage(
                        ref world,
                        explorer_id,
                        current_health,
                        position,
                        monster.monster_type,
                        monster_damage,
                    );

                    total_damage += damage_taken;

                    if new_hp <= 0 {
                        explorer_died = true;
                    } else {
                        // Update current_health for next attack iteration
                        current_health = ExplorerHealth {
                            explorer_id,
                            current_hp: new_hp,
                            max_hp: current_health.max_hp,
                            is_dead: false,
                        };
                    }
                }

                attack_num += 1;
            };

            (total_damage, explorer_died)
        }

        // ── Sneak Attack helper (task 2.7) ───────────────────────────────────

        /// Returns the number of Sneak Attack dice for a Rogue at the given level.
        /// Level 1-2: 1d6, level 3-4: 2d6, level 5: 3d6.
        fn sneak_attack_dice(level: u8) -> u8 {
            if level >= 5 {
                3
            } else if level >= 3 {
                2
            } else {
                1
            }
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl CombatSystemImpl of ICombatSystem<ContractState> {
        fn attack(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Load explorer state
            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.class != ExplorerClass::None, 'explorer does not exist');

            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.in_combat, 'not in combat');

            let inventory: ExplorerInventory = world.read_model(explorer_id);
            let combat: ExplorerCombat = world.read_model(explorer_id);

            // Load monster instance
            let monster: MonsterInstance = world.read_model(
                (position.temple_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster is already dead');

            let monster_stats = get_monster_stats(monster.monster_type);

            // ── Determine number of attacks ──────────────────────────────────
            // Fighter level 5+: Extra Attack (two attacks per turn).
            let num_attacks: u8 = if stats.class == ExplorerClass::Fighter && stats.level >= 5 {
                2
            } else {
                1
            };

            // ── Weapon and ability setup ─────────────────────────────────────
            let weapon = inventory.primary_weapon;
            let uses_dex = InternalImpl::weapon_uses_dex(weapon);
            let ability_score: u8 = if uses_dex { stats.dexterity } else { stats.strength };
            let ability_mod: i8 = ability_modifier(ability_score);
            let prof_bonus: u8 = proficiency_bonus(stats.level);

            // Fighter Champion: crit on 19-20 at level 3+
            let crit_threshold: u8 = if stats.class == ExplorerClass::Fighter && stats.level >= 3 {
                19
            } else {
                20
            };

            let mut total_damage_dealt: u16 = 0;
            let mut monster_current_hp = monster.current_hp;
            let mut monster_killed: bool = false;
            let mut first_attack_roll: u8 = 0;

            // ── Explorer attacks (with Extra Attack support) ──────────────────
            let mut atk_num: u8 = 0;
            loop {
                if atk_num >= num_attacks || monster_killed {
                    break;
                }

                let attack_roll: u8 = roll_d20(caller);
                if atk_num == 0 {
                    first_attack_roll = attack_roll;
                }

                let is_nat_1: bool = attack_roll == 1;
                let is_crit: bool = attack_roll >= crit_threshold;

                let total_attack: i16 = attack_roll.into()
                    + ability_mod.into()
                    + prof_bonus.into();

                let hits: bool = !is_nat_1
                    && (is_crit || total_attack >= monster_stats.ac.into());

                if hits {
                    let dice_sides: u8 = InternalImpl::weapon_damage_sides(weapon);
                    let base_count: u8 = InternalImpl::weapon_damage_count(weapon);
                    let dice_count: u8 = if is_crit { base_count * 2 } else { base_count };

                    let raw_damage: u16 = roll_dice(caller, dice_sides, dice_count);

                    // ── Rogue: Sneak Attack bonus (task 2.7) ─────────────────
                    // Rogue gets Sneak Attack when in combat (they have "advantage" by
                    // context — the monster is engaged). Add extra d6 dice.
                    let sneak_bonus: u16 = if stats.class == ExplorerClass::Rogue {
                        let sneak_dice: u8 = InternalImpl::sneak_attack_dice(stats.level);
                        let sneak_count: u8 = if is_crit { sneak_dice * 2 } else { sneak_dice };
                        roll_dice(caller, 6, sneak_count)
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

            // ── Write final monster state ────────────────────────────────────
            if monster_killed {
                world.write_model(@MonsterInstance {
                    temple_id: position.temple_id,
                    chamber_id: position.chamber_id,
                    monster_id: position.combat_monster_id,
                    monster_type: monster.monster_type,
                    current_hp: monster_current_hp,
                    max_hp: monster.max_hp,
                    is_alive: false,
                });

                world.write_model(@ExplorerPosition {
                    explorer_id,
                    temple_id: position.temple_id,
                    chamber_id: position.chamber_id,
                    in_combat: false,
                    combat_monster_id: 0,
                });
            } else {
                world.write_model(@MonsterInstance {
                    temple_id: position.temple_id,
                    chamber_id: position.chamber_id,
                    monster_id: position.combat_monster_id,
                    monster_type: monster.monster_type,
                    current_hp: monster_current_hp,
                    max_hp: monster.max_hp,
                    is_alive: true,
                });
            }

            // ── Monster counter-attack (task 2.5) ────────────────────────────
            // Only counter-attacks if the monster survived.
            let mut damage_taken: u16 = 0;
            if !monster_killed {
                let updated_health: ExplorerHealth = world.read_model(explorer_id);
                if !updated_health.is_dead {
                    let updated_monster = MonsterInstance {
                        temple_id: position.temple_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: monster_current_hp,
                        max_hp: monster.max_hp,
                        is_alive: true,
                    };
                    let (dmg, _died) = InternalImpl::monster_turn(
                        ref world,
                        caller,
                        explorer_id,
                        stats,
                        updated_health,
                        combat,
                        position,
                        updated_monster,
                    );
                    damage_taken = dmg;
                }
            }

            // ── Emit CombatResult ────────────────────────────────────────────
            world.emit_event(@CombatResult {
                explorer_id,
                action: CombatAction::Attack,
                roll: first_attack_roll,
                damage_dealt: total_damage_dealt,
                damage_taken,
                monster_killed,
            });
        }

        // ── Task 2.6: Fighter features ───────────────────────────────────────

        /// Fighter: Second Wind — heal 1d10 + level HP, usable once per rest.
        fn second_wind(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.class == ExplorerClass::Fighter, 'only fighters can second wind');

            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let mut combat: ExplorerCombat = world.read_model(explorer_id);
            assert(!combat.second_wind_used, 'second wind already used');

            // Roll 1d10 + level
            let heal_roll: u16 = roll_dice(caller, 10, 1);
            let heal_total: u16 = heal_roll + stats.level.into();

            // Clamp to max HP
            let new_hp_i16: i16 = health.current_hp + heal_total.try_into().unwrap();
            let new_hp: i16 = if new_hp_i16 > health.max_hp.try_into().unwrap() {
                health.max_hp.try_into().unwrap()
            } else {
                new_hp_i16
            };

            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: new_hp,
                max_hp: health.max_hp,
                is_dead: false,
            });

            combat.second_wind_used = true;
            world.write_model(@combat);

            world.emit_event(@CombatResult {
                explorer_id,
                action: CombatAction::SecondWind,
                roll: heal_roll.try_into().unwrap(),
                damage_dealt: 0,
                damage_taken: 0,
                monster_killed: false,
            });
        }

        // ── Task 2.7: Rogue features ─────────────────────────────────────────

        /// Rogue: Cunning Action — disengage from combat without the monster
        /// getting a counter-attack. Clears in_combat flag.
        fn cunning_action(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.class == ExplorerClass::Rogue, 'only rogues can cunning action');
            assert(stats.level >= 2, 'cunning action needs level 2');

            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.in_combat, 'not in combat');

            // Disengage: exit combat with no counter-attack
            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: position.temple_id,
                chamber_id: position.chamber_id,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.emit_event(@CombatResult {
                explorer_id,
                action: CombatAction::CunningAction,
                roll: 0,
                damage_dealt: 0,
                damage_taken: 0,
                monster_killed: false,
            });
        }

        // ── Stubs for later tasks ────────────────────────────────────────────

        fn cast_spell(ref self: ContractState, explorer_id: u128, spell_id: SpellId) {
            // Implemented in task 2.8
            assert(false, 'not implemented');
        }

        fn use_item(ref self: ContractState, explorer_id: u128, item_type: ItemType) {
            // Implemented in task 2.8
            assert(false, 'not implemented');
        }

        fn flee(ref self: ContractState, explorer_id: u128) {
            // Implemented in task 2.10
            assert(false, 'not implemented');
        }
    }
}
