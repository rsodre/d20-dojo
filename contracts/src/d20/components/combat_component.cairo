
#[starknet::component]
pub mod CombatComponent {
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    use d20::d20::types::index::CombatAction;
    use d20::d20::types::items::{WeaponTypeTrait, ItemType};
    use d20::d20::types::spells::{SpellId, SpellIdTrait};
    use d20::d20::types::adventurer_class::{AdventurerClass, AdventurerClassTrait};
    use d20::d20::models::adventurer::{
        AdventurerStats, AdventurerHealth, AdventurerCombat, AdventurerInventory, AdventurerPosition,
    };
    use d20::d20::models::dungeon::{MonsterInstance, AdventurerDungeonProgress, DungeonState};
    use d20::events::{CombatResult, LevelUp, BossDefeated};
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
            adventurer_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class != AdventurerClass::None, 'explorer does not exist');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let position: AdventurerPosition = world.read_model(adventurer_id);
            assert(position.in_combat, 'not in combat');

            let inventory: AdventurerInventory = world.read_model(adventurer_id);
            let combat: AdventurerCombat = world.read_model(adventurer_id);

            let monster: MonsterInstance = world.read_model(
                (position.dungeon_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster is already dead');

            let monster_stats = monster.monster_type.get_stats();

            // Fighter level 5+: Extra Attack
            let num_attacks: u8 = if stats.adventurer_class == AdventurerClass::Fighter
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
            let crit_threshold: u8 = if stats.adventurer_class == AdventurerClass::Fighter
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
                    let sneak_bonus: u16 = if stats.adventurer_class == AdventurerClass::Rogue {
                        let sneak_dice: u8 = stats.adventurer_class.sneak_attack_dice(stats.level);
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
                world.write_model(@AdventurerPosition {
                    adventurer_id,
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    in_combat: false,
                    combat_monster_id: 0,
                });
                // Award XP for the kill
                gain_xp(ref world, ref seeder, adventurer_id, position.dungeon_id, monster_stats.xp_reward);
                // Check for boss defeat
                check_boss_defeat(
                    ref world, adventurer_id, position.dungeon_id,
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
                let updated_health: AdventurerHealth = world.read_model(adventurer_id);
                if !updated_health.is_dead {
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
                        ref world, ref seeder, adventurer_id, stats, updated_health,
                        combat, position, updated_monster,
                    );
                    damage_taken = dmg;
                }
            }

            world.emit_event(@CombatResult {
                adventurer_id,
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
            adventurer_id: u128,
            spell_id: SpellId,
            ref seeder: Seeder,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class == AdventurerClass::Wizard, 'only wizards cast spells');
            assert(stats.adventurer_class != AdventurerClass::None, 'explorer does not exist');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let position: AdventurerPosition = world.read_model(adventurer_id);

            // Consume spell slot if leveled
            let slot_level: u8 = spell_id.level();
            if slot_level > 0 {
                assert(position.in_combat || slot_level == 1, 'must be in combat');
                consume_spell_slot(ref world, adventurer_id, slot_level);
            }

            // INT modifier for spell attack rolls and save DCs
            let int_mod: i8 = ability_modifier(stats.abilities.intelligence);
            let prof_bonus: u8 = proficiency_bonus(stats.level);

            let mut damage_dealt: u16 = 0;
            let mut monster_killed: bool = false;
            let mut spell_roll: u8 = 0;
            let mut xp_to_award: u32 = 0;

            match spell_id {
                SpellId::None => { assert(false, 'invalid spell'); },

                // ── Cantrips ─────────────────────────────────────────────────

                // Fire Bolt: ranged attack roll + 1d10 fire damage
                SpellId::FireBolt => {
                    assert(position.in_combat, 'no target');
                    let monster: MonsterInstance = world.read_model(
                        (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                    );
                    assert(monster.is_alive, 'monster is already dead');
                    let monster_stats = monster.monster_type.get_stats();
                    xp_to_award = monster_stats.xp_reward;

                    let attack_roll: u8 = roll_d20(ref seeder);
                    spell_roll = attack_roll;
                    let is_nat_1: bool = attack_roll == 1;
                    let is_nat_20: bool = attack_roll == 20;
                    let total_atk: i16 = attack_roll.into() + int_mod.into() + prof_bonus.into();
                    let hits: bool = !is_nat_1
                        && (is_nat_20 || total_atk >= monster_stats.ac.into());

                    if hits {
                        let dice_count: u8 = if is_nat_20 { 2 } else { 1 };
                        damage_dealt = roll_dice(ref seeder, 10, dice_count); // 1d10 (2d10 on crit)
                        let new_hp: i16 = monster.current_hp - damage_dealt.try_into().unwrap();
                        monster_killed = new_hp <= 0;
                        world.write_model(@MonsterInstance {
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            monster_id: position.combat_monster_id,
                            monster_type: monster.monster_type,
                            current_hp: new_hp,
                            max_hp: monster.max_hp,
                            is_alive: !monster_killed,
                        });
                        if monster_killed {
                            world.write_model(@AdventurerPosition {
                                adventurer_id,
                                dungeon_id: position.dungeon_id,
                                chamber_id: position.chamber_id,
                                in_combat: false,
                                combat_monster_id: 0,
                            });
                        }
                    }
                },

                // Mage Hand / Light: utility — no combat effect
                SpellId::MageHand | SpellId::Light => {},

                // ── 1st level spells ─────────────────────────────────────────

                // Magic Missile: 3 darts, each 1d4+1, auto-hit (no attack roll)
                SpellId::MagicMissile => {
                    assert(position.in_combat, 'no target');
                    let monster: MonsterInstance = world.read_model(
                        (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                    );
                    assert(monster.is_alive, 'monster is already dead');
                    xp_to_award = monster.monster_type.get_stats().xp_reward;

                    // 3 × (1d4+1): roll 3d4 then add 3
                    let raw: u16 = roll_dice(ref seeder, 4, 3);
                    damage_dealt = raw + 3; // +1 per dart
                    spell_roll = 0; // auto-hit, no roll to report

                    let new_hp: i16 = monster.current_hp - damage_dealt.try_into().unwrap();
                    monster_killed = new_hp <= 0;
                    world.write_model(@MonsterInstance {
                        dungeon_id: position.dungeon_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: new_hp,
                        max_hp: monster.max_hp,
                        is_alive: !monster_killed,
                    });
                    if monster_killed {
                        world.write_model(@AdventurerPosition {
                            adventurer_id,
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            in_combat: false,
                            combat_monster_id: 0,
                        });
                    }
                },

                // Shield: +5 AC reaction — applies until start of next turn.
                // Modeled as a permanent AC bump (reset on rest via task 2.3).
                SpellId::ShieldSpell => {
                    let mut combat_state: AdventurerCombat = world.read_model(adventurer_id);
                    combat_state.armor_class += 5;
                    world.write_model(@combat_state);
                },

                // Sleep: 5d8 HP worth of creatures fall asleep.
                // In v1, single-target — if monster's current HP ≤ roll, it is
                // incapacitated (set is_alive=false, no XP; future task can add
                // "sleeping" state). For simplicity: treat as kill if HP ≤ roll.
                SpellId::Sleep => {
                    assert(position.in_combat, 'no target');
                    let monster: MonsterInstance = world.read_model(
                        (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                    );
                    assert(monster.is_alive, 'monster is already dead');
                    xp_to_award = monster.monster_type.get_stats().xp_reward;

                    let sleep_pool: u16 = roll_dice(ref seeder, 8, 5); // 5d8
                    spell_roll = (sleep_pool % 256).try_into().unwrap(); // store low byte for event

                    // Monster falls asleep if its current HP ≤ sleep pool
                    if monster.current_hp <= sleep_pool.try_into().unwrap() {
                        monster_killed = true; // "incapacitated" — treated as removed from combat
                        world.write_model(@MonsterInstance {
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            monster_id: position.combat_monster_id,
                            monster_type: monster.monster_type,
                            current_hp: monster.current_hp,
                            max_hp: monster.max_hp,
                            is_alive: false,
                        });
                        world.write_model(@AdventurerPosition {
                            adventurer_id,
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            in_combat: false,
                            combat_monster_id: 0,
                        });
                    }
                },

                // ── 2nd level spells ─────────────────────────────────────────

                // Scorching Ray: 3 rays, each is an attack roll + 2d6 fire damage
                SpellId::ScorchingRay => {
                    assert(position.in_combat, 'no target');
                    let mut monster: MonsterInstance = world.read_model(
                        (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                    );
                    assert(monster.is_alive, 'monster is already dead');
                    let monster_stats = monster.monster_type.get_stats();
                    xp_to_award = monster_stats.xp_reward;

                    let mut ray: u8 = 0;
                    while ray < 3 && !monster_killed {
                        let ray_roll: u8 = roll_d20(ref seeder);
                        if ray == 0 {
                            spell_roll = ray_roll;
                        }
                        let is_nat_1: bool = ray_roll == 1;
                        let is_nat_20: bool = ray_roll == 20;
                        let total_atk: i16 = ray_roll.into() + int_mod.into() + prof_bonus.into();
                        let hits: bool = !is_nat_1
                            && (is_nat_20 || total_atk >= monster_stats.ac.into());

                        if hits {
                            let dice_count: u8 = if is_nat_20 { 4 } else { 2 }; // 2d6 (4d6 crit)
                            let ray_dmg: u16 = roll_dice(ref seeder, 6, dice_count);
                            damage_dealt += ray_dmg;
                            let new_hp: i16 = monster.current_hp - ray_dmg.try_into().unwrap();
                            monster.current_hp = new_hp;
                            if new_hp <= 0 {
                                monster_killed = true;
                            }
                        }
                        ray += 1;
                    };

                    world.write_model(@MonsterInstance {
                        dungeon_id: position.dungeon_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: monster.current_hp,
                        max_hp: monster.max_hp,
                        is_alive: !monster_killed,
                    });
                    if monster_killed {
                        world.write_model(@AdventurerPosition {
                            adventurer_id,
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            in_combat: false,
                            combat_monster_id: 0,
                        });
                    }
                },

                // Misty Step: teleport utility — no combat damage.
                // Combat effect: disengage (clears in_combat without counter-attack).
                SpellId::MistyStep => {
                    if position.in_combat {
                        world.write_model(@AdventurerPosition {
                            adventurer_id,
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            in_combat: false,
                            combat_monster_id: 0,
                        });
                    }
                },

                // ── 3rd level spells ─────────────────────────────────────────

                // Fireball: 8d6 fire, DEX saving throw (DC 8 + INT mod + prof) for half.
                // Single-target in v1 (no AOE chamber logic yet).
                SpellId::Fireball => {
                    assert(position.in_combat, 'no target');
                    let monster: MonsterInstance = world.read_model(
                        (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                    );
                    assert(monster.is_alive, 'monster is already dead');
                    let monster_stats = monster.monster_type.get_stats();
                    xp_to_award = monster_stats.xp_reward;

                    // DC = 8 + INT mod + proficiency bonus
                    let save_dc: i16 = 8_i16 + int_mod.into() + prof_bonus.into();

                    // Monster DEX saving throw: d20 + DEX mod vs DC
                    let save_roll: u8 = roll_d20(ref seeder);
                    spell_roll = save_roll;
                    let monster_dex_mod: i8 = ability_modifier(monster_stats.dexterity);
                    let save_total: i16 = save_roll.into() + monster_dex_mod.into();
                    let save_succeeds: bool = save_total >= save_dc;

                    let raw_dmg: u16 = roll_dice(ref seeder, 6, 8); // 8d6

                    // Half damage on successful save (integer floor division)
                    damage_dealt = if save_succeeds { raw_dmg / 2 } else { raw_dmg };

                    let new_hp: i16 = monster.current_hp - damage_dealt.try_into().unwrap();
                    monster_killed = new_hp <= 0;
                    world.write_model(@MonsterInstance {
                        dungeon_id: position.dungeon_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: new_hp,
                        max_hp: monster.max_hp,
                        is_alive: !monster_killed,
                    });
                    if monster_killed {
                        world.write_model(@AdventurerPosition {
                            adventurer_id,
                            dungeon_id: position.dungeon_id,
                            chamber_id: position.chamber_id,
                            in_combat: false,
                            combat_monster_id: 0,
                        });
                    }
                },
            }

            // Award XP and check for boss defeat on kill
            if monster_killed && xp_to_award > 0 {
                gain_xp(ref world, ref seeder, adventurer_id, position.dungeon_id, xp_to_award);
            }
            if monster_killed {
                // Re-read the monster type from the MonsterInstance (xp_to_award==0 for
                // MistyStep/Shield which never kill, so this only fires on real kills)
                let killed_monster: MonsterInstance = world.read_model(
                    (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                );
                check_boss_defeat(
                    ref world, adventurer_id, position.dungeon_id,
                    position.chamber_id, killed_monster.monster_type,
                );
            }

            // ── Monster counter-attack (unless killed or disengaged) ──────────
            // Shield and MistyStep don't kill the monster; Shield stays in combat,
            // MistyStep disengages. Only counter-attack when still in_combat.
            let mut damage_taken: u16 = 0;
            if !monster_killed {
                // Re-read position — MistyStep may have cleared in_combat
                let updated_position: AdventurerPosition = world.read_model(adventurer_id);
                if updated_position.in_combat {
                    let updated_health: AdventurerHealth = world.read_model(adventurer_id);
                    if !updated_health.is_dead {
                        let updated_combat: AdventurerCombat = world.read_model(adventurer_id);
                        let live_monster: MonsterInstance = world.read_model(
                            (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                        );
                        let (dmg, _died) = monster_turn(
                            ref world, ref seeder, adventurer_id, stats, updated_health,
                            updated_combat, updated_position, live_monster,
                        );
                        damage_taken = dmg;
                    }
                }
            }

            world.emit_event(@CombatResult {
                adventurer_id,
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
            adventurer_id: u128,
            item_type: ItemType,
            ref seeder: Seeder,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class != AdventurerClass::None, 'explorer does not exist');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            match item_type {
                ItemType::None => { assert(false, 'no item specified'); },
                ItemType::HealthPotion => {
                    let mut inventory: AdventurerInventory = world.read_model(adventurer_id);
                    assert(inventory.potions > 0, 'no potions remaining');
                    inventory.potions -= 1;
                    world.write_model(@inventory);

                    // Heal 2d4+2
                    let raw_heal: u16 = roll_dice(ref seeder, 4, 2);
                    let heal_total: u16 = raw_heal + 2;

                    let new_hp_i16: i16 = health.current_hp + heal_total.try_into().unwrap();
                    let new_hp: i16 = if new_hp_i16 > health.max_hp.try_into().unwrap() {
                        health.max_hp.try_into().unwrap()
                    } else {
                        new_hp_i16
                    };

                    world.write_model(@AdventurerHealth {
                        adventurer_id,
                        current_hp: new_hp,
                        max_hp: health.max_hp,
                        is_dead: false,
                    });

                    // Monster counter-attacks after using item (if in combat)
                    let position: AdventurerPosition = world.read_model(adventurer_id);
                    let mut damage_taken: u16 = 0;
                    if position.in_combat {
                        let updated_health: AdventurerHealth = world.read_model(adventurer_id);
                        let combat: AdventurerCombat = world.read_model(adventurer_id);
                        let monster: MonsterInstance = world.read_model(
                            (position.dungeon_id, position.chamber_id, position.combat_monster_id)
                        );
                        if monster.is_alive {
                            let (dmg, _died) = monster_turn(
                                ref world, ref seeder, adventurer_id, stats, updated_health,
                                combat, position, monster,
                            );
                            damage_taken = dmg;
                        }
                    }

                    world.emit_event(@CombatResult {
                        adventurer_id,
                        action: CombatAction::UseItem,
                        roll: raw_heal.try_into().unwrap(),
                        damage_dealt: 0,
                        damage_taken,
                        monster_killed: false,
                    });
                },
            }
        }

        /// Fighter: heal 1d10 + level once per rest.
        fn second_wind(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            adventurer_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class == AdventurerClass::Fighter, 'only fighters can second wind');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let mut combat: AdventurerCombat = world.read_model(adventurer_id);
            assert(!combat.second_wind_used, 'second wind already used');

            let heal_roll: u16 = roll_dice(ref seeder, 10, 1);
            let heal_total: u16 = heal_roll + stats.level.into();

            let new_hp_i16: i16 = health.current_hp + heal_total.try_into().unwrap();
            let new_hp: i16 = if new_hp_i16 > health.max_hp.try_into().unwrap() {
                health.max_hp.try_into().unwrap()
            } else {
                new_hp_i16
            };

            world.write_model(@AdventurerHealth {
                adventurer_id,
                current_hp: new_hp,
                max_hp: health.max_hp,
                is_dead: false,
            });

            combat.second_wind_used = true;
            world.write_model(@combat);

            world.emit_event(@CombatResult {
                adventurer_id,
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
            adventurer_id: u128,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class == AdventurerClass::Rogue, 'only rogues can cunning action');
            assert(stats.level >= 2, 'cunning action needs level 2');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let position: AdventurerPosition = world.read_model(adventurer_id);
            assert(position.in_combat, 'not in combat');

            world.write_model(@AdventurerPosition {
                adventurer_id,
                dungeon_id: position.dungeon_id,
                chamber_id: position.chamber_id,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.emit_event(@CombatResult {
                adventurer_id,
                action: CombatAction::CunningAction,
                roll: 0,
                damage_dealt: 0,
                damage_taken: 0,
                monster_killed: false,
            });
        }

        /// Contested DEX check: roll d20 + explorer DEX mod vs roll d20 + monster DEX mod.
        /// On success: explorer disengages (clears in_combat) — no counter-attack.
        /// On failure: monster gets a free counter-attack.
        fn flee(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            adventurer_id: u128,
            ref seeder: Seeder,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class != AdventurerClass::None, 'explorer does not exist');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorer cannot act');

            let mut position: AdventurerPosition = world.read_model(adventurer_id);
            assert(position.in_combat, 'not in combat');

            let monster: MonsterInstance = world.read_model(
                (position.dungeon_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster already dead');

            // Adventurer DEX roll: d20 + DEX modifier
            let adventurer_roll: u8 = roll_d20(ref seeder);
            let adventurer_dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
            let adventurer_dex_mod_i32: i32 = adventurer_dex_mod.into();
            let adventurer_roll_i32: i32 = adventurer_roll.into();
            let adventurer_total: i32 = adventurer_roll_i32 + adventurer_dex_mod_i32;

            // Monster DEX roll: d20 + monster DEX modifier
            let monster_stats = monster.monster_type.get_stats();
            let monster_roll: u8 = roll_d20(ref seeder);
            let monster_dex_mod: i8 = ability_modifier(monster_stats.dexterity);
            let monster_dex_mod_i32: i32 = monster_dex_mod.into();
            let monster_roll_i32: i32 = monster_roll.into();
            let monster_total: i32 = monster_roll_i32 + monster_dex_mod_i32;

            // adventurer wins ties (they initiated the flee)
            let flee_success = adventurer_total >= monster_total;

            let mut damage_taken: u16 = 0;

            if flee_success {
                // Clear combat — adventurer disengages
                world.write_model(@AdventurerPosition {
                    adventurer_id,
                    dungeon_id: position.dungeon_id,
                    chamber_id: position.chamber_id,
                    in_combat: false,
                    combat_monster_id: 0,
                });
            } else {
                // Monster gets a free counter-attack on failed flee
                let combat: AdventurerCombat = world.read_model(adventurer_id);
                let (dmg, _died) = monster_turn(
                    ref world, ref seeder, adventurer_id, stats, health, combat, position, monster,
                );
                damage_taken = dmg;
            }

            world.emit_event(@CombatResult {
                adventurer_id,
                action: CombatAction::Flee,
                roll: adventurer_roll,
                damage_dealt: 0,
                damage_taken,
                monster_killed: false,
            });
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /// Execute the monster's counter-attack against the adventurer.
    /// Returns (damage_taken, adventurer_died).
    fn monster_turn(
        ref world: WorldStorage,
        ref seeder: Seeder,
        adventurer_id: u128,
        stats: AdventurerStats,
        health: AdventurerHealth,
        combat: AdventurerCombat,
        position: AdventurerPosition,
        monster: MonsterInstance,
    ) -> (u16, bool) {
        let monster_stats = monster.monster_type.get_stats();

        let mut total_damage: u16 = 0;
        let mut adventurer_died: bool = false;
        let mut current_health = health;

        let mut attack_num: u8 = 0;
        while attack_num < monster_stats.num_attacks && !adventurer_died {
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
                let new_hp: i16 = current_health.current_hp - damage_i16;

                let damage_taken = DamageTrait::apply_adventurer_damage(
                    ref world,
                    adventurer_id,
                    current_health,
                    position,
                    monster.monster_type,
                    monster_damage,
                );

                total_damage += damage_taken;

                if new_hp <= 0 {
                    adventurer_died = true;
                } else {
                    current_health = AdventurerHealth {
                        adventurer_id,
                        current_hp: new_hp,
                        max_hp: current_health.max_hp,
                        is_dead: false,
                    };
                }
            }

            attack_num += 1;
        };

        (total_damage, adventurer_died)
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
        adventurer_id: u128,
        stats: AdventurerStats,
        health: AdventurerHealth,
    ) {
        let new_level: u8 = stats.level + 1;

        // Update level in AdventurerStats
        world.write_model(@AdventurerStats {
            adventurer_id,
            abilities: stats.abilities,
            level: new_level,
            xp: stats.xp,
            adventurer_class: stats.adventurer_class,
            dungeons_conquered: stats.dungeons_conquered,
        });

        // Roll hit die + CON modifier, minimum 1, add to max HP
        let hit_sides: u8 = stats.adventurer_class.hit_die_max();
        let raw_roll: u16 = roll_dice(ref seeder, hit_sides, 1);
        let con_mod: i8 = ability_modifier(stats.abilities.constitution);
        let raw_roll_i32: i32 = raw_roll.into();
        let con_mod_i32: i32 = con_mod.into();
        let hp_gain_i32: i32 = raw_roll_i32 + con_mod_i32;
        let hp_gain: u16 = if hp_gain_i32 < 1 { 1 } else { hp_gain_i32.try_into().unwrap() };
        let new_max_hp: u16 = health.max_hp + hp_gain;

        world.write_model(@AdventurerHealth {
            adventurer_id,
            current_hp: health.current_hp,
            max_hp: new_max_hp,
            is_dead: false,
        });

        // Update spell slots for Wizards
        if stats.adventurer_class == AdventurerClass::Wizard {
            let combat: AdventurerCombat = world.read_model(adventurer_id);
            let (slots_1, slots_2, slots_3) = stats.adventurer_class.spell_slots_for(new_level);
            world.write_model(@AdventurerCombat {
                adventurer_id,
                armor_class: combat.armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: combat.second_wind_used,
                action_surge_used: combat.action_surge_used,
            });
        }

        world.emit_event(@LevelUp { adventurer_id, new_level });
    }

    /// Award XP to the adventurer for killing a monster.
    /// Updates AdventurerStats.xp and AdventurerDungeonProgress.xp_earned.
    /// Triggers level_up if an XP threshold is crossed (max level 5).
    fn gain_xp(
        ref world: WorldStorage,
        ref seeder: Seeder,
        adventurer_id: u128,
        dungeon_id: u128,
        xp_reward: u32,
    ) {
        let mut stats: AdventurerStats = world.read_model(adventurer_id);

        // Don't grant XP beyond level 5
        if stats.level >= 5 {
            return;
        }

        let new_xp: u32 = stats.xp + xp_reward;
        stats.xp = new_xp;
        world.write_model(@stats);

        // Update dungeon progress XP
        if dungeon_id != 0 {
            let mut progress: AdventurerDungeonProgress = world.read_model((adventurer_id, dungeon_id));
            world.write_model(@AdventurerDungeonProgress {
                adventurer_id,
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
                let current_stats: AdventurerStats = world.read_model(adventurer_id);
                let current_health: AdventurerHealth = world.read_model(adventurer_id);
                level_up(ref world, ref seeder, adventurer_id, current_stats, current_health);
                current_level += 1;
            } else {
                break;
            }
        };
    }

    /// Check if the just-killed monster was the boss. If so:
    ///   1. Mark DungeonState.boss_alive = false.
    ///   2. Increment AdventurerStats.dungeons_conquered.
    ///   3. Emit BossDefeated event.
    fn check_boss_defeat(
        ref world: WorldStorage,
        adventurer_id: u128,
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

        // Increment dungeons_conquered on the adventurer
        let mut stats: AdventurerStats = world.read_model(adventurer_id);
        stats.dungeons_conquered += 1;
        world.write_model(@stats);

        // Emit BossDefeated event
        world.emit_event(@BossDefeated { dungeon_id, adventurer_id, monster_type });
    }

    /// Consume a spell slot of the given level. Panics if none available.
    fn consume_spell_slot(ref world: WorldStorage, adventurer_id: u128, level: u8) {
        let mut combat: AdventurerCombat = world.read_model(adventurer_id);
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
