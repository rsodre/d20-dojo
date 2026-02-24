
#[starknet::component]
pub mod DungeonComponent {
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    use d20::d20::types::character_class::CharacterClass;
    use d20::d20::types::items::{WeaponType, ArmorType};
    use d20::d20::models::monster::{MonsterType, MonsterTypeTrait};
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberType,
        MonsterInstance, ChamberExit, CharacterDungeonProgress,
        FallenCharacter,
    };
    use d20::d20::models::character::{
        CharacterStats, CharacterPosition, CharacterInventory,
        CharacterSkills, Skill,
    };
    use d20::d20::types::damage::DamageTrait;
    use d20::d20::models::events::ChamberRevealed;
    use d20::utils::dice::{roll_d20, roll_dice, ability_modifier, proficiency_bonus};
    use d20::utils::seeder::{Seeder, SeederTrait};

    // ── Boss probability constants (Depth Formula) ──────────────────────────
    // See SPEC.md §"Boss Chamber Probability"
    const MIN_DEPTH: u8 = 5;
    const DEPTH_WEIGHT: u32 = 50;  // bps per effective_depth²
    const XP_WEIGHT: u32 = 2;       // bps per xp_earned
    const MAX_PROB: u32 = 9500;     // cap at 95%

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Initialize DungeonState, entrance Chamber, and exit stubs for a newly minted dungeon.
        fn init_dungeon(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            dungeon_id: u128,
            difficulty: u8,
        ) {
            // Initialize DungeonState (max_depth=1 because entrance is at depth 1)
            world.write_model(@DungeonState {
                dungeon_id,
                difficulty_tier: difficulty,
                next_chamber_id: 2, // chamber 1 is the entrance; next new chamber gets id 2
                boss_chamber_id: 0,
                boss_alive: true,
                max_depth: 1,
            });

            // Create entrance Chamber (id=1, depth=1, always 3 exits)
            let entrance_exit_count: u8 = 3;
            world.write_model(@Chamber {
                dungeon_id,
                chamber_id: 1,
                chamber_type: ChamberType::Entrance,
                depth: 1,
                exit_count: entrance_exit_count,
                is_revealed: true,
                treasure_looted: false,
                trap_disarmed: false,
                trap_dc: 0,
            fallen_count: 0,
            });

            // Write undiscovered exit stubs so open_exit can validate bounds
            let mut i: u8 = 0;
            while i < entrance_exit_count {
                world.write_model(@ChamberExit {
                    dungeon_id,
                    from_chamber_id: 1,
                    exit_index: i,
                    to_chamber_id: 0,
                    is_discovered: false,
                });
                i += 1;
            };
        }

        /// Place an character at the dungeon's entrance chamber.
        fn enter_dungeon(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            dungeon_id: u128,
        ) {
            // Validate dungeon exists
            let dungeon: DungeonState = world.read_model(dungeon_id);
            assert(dungeon.difficulty_tier >= 1, 'dungeon does not exist');

            // Validate character is alive
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot enter');

            // Validate character is not in combat
            let position: CharacterPosition = world.read_model(character_id);
            assert(!position.in_combat, 'character is in combat');

            // Place character at entrance chamber (overwrites any previous dungeon position)
            world.write_model(@CharacterPosition {
                character_id,
                dungeon_id,
                chamber_id: 1, // entrance chamber is always id 1
                in_combat: false,
                combat_monster_id: 0,
            });

            // Initialize CharacterDungeonProgress for this dungeon visit
            // (only write if not previously set — existing chambers_explored/xp_earned carry over
            //  from prior visits, so we only initialize on a fresh record)
            let progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));
            if progress.chambers_explored == 0 && progress.xp_earned == 0 {
                world.write_model(@CharacterDungeonProgress {
                    character_id,
                    dungeon_id,
                    chambers_explored: 0,
                    xp_earned: 0,
                });
            }
        }

        /// Remove an character from the dungeon (set dungeon_id=0, chamber_id=0).
        fn exit_dungeon(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
        ) {
            // Validate character is in a dungeon
            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot exit during combat');

            // Clear dungeon/chamber position — stats, inventory, XP, and
            // CharacterDungeonProgress are all untouched (persisted on-chain).
            world.write_model(@CharacterPosition {
                character_id,
                dungeon_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });
        }

        /// Open an unexplored exit from the character's current chamber,
        /// generating the destination chamber if it hasn't been discovered yet.
        fn open_exit(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            exit_index: u8,
            ref seeder: Seeder,
        ) {
            // ── Validate character state ──────────────────────────────────────
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot explore');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot open exit in combat');

            let dungeon_id = position.dungeon_id;
            let current_chamber_id = position.chamber_id;

            // ── Validate the exit exists on the current chamber ──────────────
            let current_chamber: Chamber = world.read_model((dungeon_id, current_chamber_id));
            assert(exit_index < current_chamber.exit_count, 'invalid exit index');

            // ── Check if exit is already discovered ──────────────────────────
            let exit: ChamberExit = world.read_model((dungeon_id, current_chamber_id, exit_index));
            assert(!exit.is_discovered, 'exit already discovered');

            // ── Allocate new chamber ID ──────────────────────────────────────
            let mut dungeon: DungeonState = world.read_model(dungeon_id);
            let new_chamber_id: u32 = dungeon.next_chamber_id;
            dungeon.next_chamber_id = new_chamber_id + 1;
            world.write_model(@dungeon);

            // ── Read progress for boss probability ───────────────────────────
            let progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));

            // ── Generate the new chamber ─────────────────────────────────────
            let new_depth: u8 = current_chamber.depth + 1;
            generate_chamber(
                ref world,
                ref seeder,
                dungeon_id,
                current_chamber_id,
                new_chamber_id,
                new_depth,
                character_id,
                character_id, // revealed_by
                dungeon.difficulty_tier,
                progress.xp_earned,
                dungeon.max_depth,
            );

            // ── Create bidirectional ChamberExit links ───────────────────────
            // Forward: current → new (mark discovered)
            world.write_model(@ChamberExit {
                dungeon_id,
                from_chamber_id: current_chamber_id,
                exit_index,
                to_chamber_id: new_chamber_id,
                is_discovered: true,
            });

            // Back: new → current (exit_index = 0 reserved for return path)
            world.write_model(@ChamberExit {
                dungeon_id,
                from_chamber_id: new_chamber_id,
                exit_index: 0,
                to_chamber_id: current_chamber_id,
                is_discovered: true,
            });

            // ── Increment chambers_explored on CharacterDungeonProgress ──────
            world.write_model(@CharacterDungeonProgress {
                character_id,
                dungeon_id,
                chambers_explored: progress.chambers_explored + 1,
                xp_earned: progress.xp_earned,
            });
        }

        /// Move the character through a previously discovered exit.
        fn move_to_chamber(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            exit_index: u8,
            ref seeder: Seeder,
        ) {
            // ── Validate character state ──────────────────────────────────────
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot move');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot move during combat');

            let dungeon_id = position.dungeon_id;
            let current_chamber_id = position.chamber_id;

            // ── Validate exit is discovered ──────────────────────────────────
            let current_chamber: Chamber = world.read_model((dungeon_id, current_chamber_id));
            assert(exit_index < current_chamber.exit_count, 'invalid exit index');

            let exit: ChamberExit = world.read_model((dungeon_id, current_chamber_id, exit_index));
            assert(exit.is_discovered, 'exit not yet discovered');

            let dest_chamber_id = exit.to_chamber_id;

            // ── Move character to destination chamber ─────────────────────────
            let dest_chamber: Chamber = world.read_model((dungeon_id, dest_chamber_id));

            // Check for live monster in destination chamber
            let monster: MonsterInstance = world.read_model((dungeon_id, dest_chamber_id, 1_u32));
            let enters_combat: bool = monster.is_alive && dest_chamber.chamber_type == ChamberType::Monster
                || (monster.is_alive && dest_chamber.chamber_type == ChamberType::Boss);

            world.write_model(@CharacterPosition {
                character_id,
                dungeon_id,
                chamber_id: dest_chamber_id,
                in_combat: enters_combat,
                combat_monster_id: if enters_combat { 1 } else { 0 },
            });

            // ── Trigger trap on entry if not disarmed ────────────────────────
            // Trap damage dealt on entry: DEX save vs trap_dc.
            // On failed save, character takes 1d6 + depth/2 damage.
            if dest_chamber.chamber_type == ChamberType::Trap && !dest_chamber.trap_disarmed
                && dest_chamber.trap_dc > 0 {
                let stats: CharacterStats = world.read_model(character_id);
                let dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
                // DEX saving throw
                let save_roll: i16 = roll_d20(ref seeder).into() + dex_mod.into();
                let dc_i16: i16 = dest_chamber.trap_dc.into();
                if save_roll < dc_i16 {
                    // Failed save: take 1d6 + depth/2 piercing damage
                    let base_dmg: u16 = roll_dice(ref seeder, 6, 1);
                    let bonus: u16 = (dest_chamber.depth / 2).into();
                    let damage: u16 = base_dmg + bonus;
                    // Use the destination position so handle_death records the right chamber
                    let dest_position = CharacterPosition {
                        character_id,
                        dungeon_id,
                        chamber_id: dest_chamber_id,
                        in_combat: enters_combat,
                        combat_monster_id: if enters_combat { 1 } else { 0 },
                    };
                    DamageTrait::apply_character_damage(
                        ref world, character_id, stats, dest_position, MonsterType::None, damage,
                    );
                }
            }
        }

        /// DEX/skill check to disarm a trap in the current chamber.
        fn disarm_trap(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            ref seeder: Seeder,
        ) {
            // ── Validate character state ──────────────────────────────────────
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot disarm');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot disarm during combat');

            let dungeon_id = position.dungeon_id;
            let chamber_id = position.chamber_id;

            // ── Must be a Trap chamber with an active trap ───────────────────
            let chamber: Chamber = world.read_model((dungeon_id, chamber_id));
            assert(chamber.chamber_type == ChamberType::Trap, 'no trap in this chamber');
            assert(!chamber.trap_disarmed, 'trap already disarmed');
            assert(chamber.trap_dc > 0, 'no trap in this chamber');

            // ── Disarm check: DEX (Rogue) or INT (others) + proficiency ──────
            // Rogues use DEX + proficiency (with expertise on Stealth/Acrobatics if selected).
            // All other classes use INT + proficiency only if proficient in Arcana.
            // Expertise on the relevant skill doubles the proficiency bonus.
            let skills: CharacterSkills = world.read_model(character_id);
            let prof: u8 = proficiency_bonus(stats.level);

            let (ability_score, prof_mult): (u8, u8) = match stats.character_class {
                CharacterClass::Rogue => {
                    // Check for expertise on Acrobatics (DEX skill → applies to fine motor work)
                    let expertise_mult: u8 = if skills.expertise_1 == Skill::Acrobatics
                        || skills.expertise_2 == Skill::Acrobatics { 2 } else { 1 };
                    (stats.abilities.dexterity, expertise_mult)
                },
                _ => {
                    // INT check; proficient only if Arcana trained
                    let arcana_mult: u8 = if skills.skills.arcana { 1 } else { 0 };
                    (stats.abilities.intelligence, arcana_mult)
                },
            };

            let ability_mod: i8 = ability_modifier(ability_score);
            let prof_bonus: i8 = (prof * prof_mult).try_into().unwrap();
            let roll: u8 = roll_d20(ref seeder);
            let total: i16 = roll.into() + ability_mod.into() + prof_bonus.into();
            let dc: i16 = chamber.trap_dc.into();

            if total >= dc {
                // ── Success: mark trap disarmed ──────────────────────────────
                world.write_model(@Chamber {
                    dungeon_id,
                    chamber_id,
                    chamber_type: chamber.chamber_type,
                    depth: chamber.depth,
                    exit_count: chamber.exit_count,
                    is_revealed: chamber.is_revealed,
                    treasure_looted: chamber.treasure_looted,
                    trap_disarmed: true,
                    trap_dc: chamber.trap_dc,
                    fallen_count: chamber.fallen_count,
                });
            } else {
                // ── Failure: trap fires — DEX save or take damage ────────────
                // Failed disarm attempt triggers the trap:
                // DEX saving throw vs trap_dc; fail → 1d6 + depth/2 damage.
                let dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
                let save_roll: i16 = roll_d20(ref seeder).into() + dex_mod.into();
                if save_roll < dc {
                    let base_dmg: u16 = roll_dice(ref seeder, 6, 1);
                    let bonus: u16 = (chamber.depth / 2).into();
                    let damage: u16 = base_dmg + bonus;
                    DamageTrait::apply_character_damage(
                        ref world, character_id, stats, position, MonsterType::None, damage,
                    );
                }
                // On success of the DEX save: no damage, but trap still armed (can retry)
            }
        }

        /// Loot the current chamber: Perception check (d20 + WIS) in Empty/Treasure chambers,
        /// awards gold and possibly a potion on success. Marks chamber as looted.
        fn loot_treasure(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            ref seeder: Seeder,
        ) {
            // ── Validate character state ──────────────────────────────────────
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot loot');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot loot during combat');

            let dungeon_id = position.dungeon_id;
            let chamber_id = position.chamber_id;

            // ── Only lootable in Empty or Treasure chambers ──────────────────
            let chamber: Chamber = world.read_model((dungeon_id, chamber_id));
            assert(
                chamber.chamber_type == ChamberType::Empty
                    || chamber.chamber_type == ChamberType::Treasure,
                'nothing to loot here'
            );
            assert(!chamber.treasure_looted, 'already looted');

            // ── Perception check: d20 + WIS mod [+ proficiency if trained] ───
            // DC 12 for Empty chambers, DC 10 for Treasure chambers
            let skills: CharacterSkills = world.read_model(character_id);

            let wis_mod: i8 = ability_modifier(stats.abilities.wisdom);
            let prof: u8 = proficiency_bonus(stats.level);
            let prof_bonus: i8 = if skills.skills.perception { prof.try_into().unwrap() } else { 0 };

            let roll: i16 = roll_d20(ref seeder).into() + wis_mod.into() + prof_bonus.into();

            let dc: i16 = if chamber.chamber_type == ChamberType::Empty { 12 } else { 10 };

            if roll >= dc {
                // ── Success: award gold and possibly a potion ─────────────────
                // Gold: 1d6 × (depth + 1) × difficulty
                let gold_roll: u32 = roll_dice(ref seeder, 6, 1).into();
                let dungeon: DungeonState = world.read_model(dungeon_id);
                let gold_found: u32 = gold_roll
                    * (chamber.depth.into() + 1)
                    * dungeon.difficulty_tier.into();

                // Potion found on total roll >= 15
                let potion_found: u8 = if roll >= 15 { 1 } else { 0 };

                let inventory: CharacterInventory = world.read_model(character_id);
                world.write_model(@CharacterInventory {
                    character_id,
                    primary_weapon: inventory.primary_weapon,
                    secondary_weapon: inventory.secondary_weapon,
                    armor: inventory.armor,
                    has_shield: inventory.has_shield,
                    gold: inventory.gold + gold_found,
                    potions: inventory.potions + potion_found,
                });

                // Mark as looted — cannot loot again
                world.write_model(@Chamber {
                    dungeon_id,
                    chamber_id,
                    chamber_type: chamber.chamber_type,
                    depth: chamber.depth,
                    exit_count: chamber.exit_count,
                    is_revealed: chamber.is_revealed,
                    treasure_looted: true,
                    trap_disarmed: chamber.trap_disarmed,
                    trap_dc: chamber.trap_dc,
                    fallen_count: chamber.fallen_count,
                });
            }
            // On failed check: nothing found, can retry next turn
        }

        /// Pick up loot from a fallen character in the current chamber.
        fn loot_fallen(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            character_id: u128,
            fallen_index: u32,
        ) {
            // ── Validate character state ──────────────────────────────────────
            let stats: CharacterStats = world.read_model(character_id);
            assert(!stats.is_dead, 'dead characters cannot loot');

            let position: CharacterPosition = world.read_model(character_id);
            assert(position.dungeon_id != 0, 'not inside any dungeon');
            assert(!position.in_combat, 'cannot loot during combat');

            let dungeon_id = position.dungeon_id;
            let chamber_id = position.chamber_id;

            // ── Validate fallen_index is in range ────────────────────────────
            let chamber: Chamber = world.read_model((dungeon_id, chamber_id));
            assert(fallen_index < chamber.fallen_count, 'no body at that index');

            // ── Read the FallenCharacter record ─────────────────────────────
            let fallen: FallenCharacter = world.read_model((dungeon_id, chamber_id, fallen_index));
            assert(!fallen.is_looted, 'already looted');

            // ── Cannot loot yourself (edge case: somehow same character_id) ─
            assert(fallen.character_id != character_id, 'cannot loot yourself');

            // ── Merge dropped loot into character's inventory ─────────────────
            // Weapons: only take if character has None in that slot
            // Armor:   only upgrade if dropped armor > current (or current is None)
            // Gold + potions: always add
            let inventory: CharacterInventory = world.read_model(character_id);

            let new_primary: WeaponType = if inventory.primary_weapon == WeaponType::None {
                fallen.dropped_weapon
            } else {
                inventory.primary_weapon
            };

            // Secondary slot: take dropped weapon if secondary is empty and primary already used it
            let new_secondary: WeaponType = if inventory.secondary_weapon == WeaponType::None
                && new_primary != fallen.dropped_weapon {
                fallen.dropped_weapon
            } else {
                inventory.secondary_weapon
            };

            // Armor: upgrade if currently wearing nothing and fallen had armor
            let new_armor: ArmorType = if inventory.armor == ArmorType::None {
                fallen.dropped_armor
            } else {
                inventory.armor
            };

            world.write_model(@CharacterInventory {
                character_id,
                primary_weapon: new_primary,
                secondary_weapon: new_secondary,
                armor: new_armor,
                has_shield: inventory.has_shield,
                gold: inventory.gold + fallen.dropped_gold,
                potions: inventory.potions + fallen.dropped_potions,
            });

            // ── Mark fallen character as looted ───────────────────────────────
            world.write_model(@FallenCharacter {
                dungeon_id,
                chamber_id,
                fallen_index,
                character_id: fallen.character_id,
                dropped_weapon: fallen.dropped_weapon,
                dropped_armor: fallen.dropped_armor,
                dropped_gold: fallen.dropped_gold,
                dropped_potions: fallen.dropped_potions,
                is_looted: true,
            });
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /// Boss probability: Depth Formula (integer-only, bps).
    fn calculate_boss_probability(depth: u8, xp_earned: u32) -> u32 {
        if depth < MIN_DEPTH {
            return 0;
        }
        let effective_depth: u32 = (depth - MIN_DEPTH).into();
        let depth_component: u32 = effective_depth * effective_depth * DEPTH_WEIGHT;
        let xp_component: u32 = xp_earned * XP_WEIGHT;
        let total: u32 = depth_component + xp_component;
        if total > MAX_PROB { MAX_PROB } else { total }
    }

    /// Monster type by depth and difficulty.
    /// Derives from a random value from the seeder.
    fn monster_for_depth(depth: u8, difficulty: u8, hash: u256) -> MonsterType {
        // Thematic progression per SPEC:
        //   depth 0-2:  Snakes, Skeletons
        //   depth 3-5:  Shadows, Animated Armor
        //   depth 6-9:  Gargoyles, Mummies
        //   depth 10+:  Mummies, (Wraith reserved for boss)
        let tier: u8 = if depth <= 2 { 0 }
            else if depth <= 5 { 1 }
            else { 2 };

        // difficulty shifts tier up by (difficulty - 1), capped
        let adjusted: u8 = tier + (difficulty - 1);
        let capped: u8 = if adjusted > 2 { 2 } else { adjusted };

        // Pick one of two monsters in tier using hash bit
        let pick: u8 = (hash % 2).try_into().unwrap();
        match capped {
            0 => if pick == 0 { MonsterType::PoisonousSnake } else { MonsterType::Skeleton },
            1 => if pick == 0 { MonsterType::Shadow } else { MonsterType::AnimatedArmor },
            _ => if pick == 0 { MonsterType::Gargoyle } else { MonsterType::Mummy },
        }
    }

    /// Creates a new chamber model derived from the dungeon seed + parent chamber.
    fn generate_chamber(
        ref world: WorldStorage,
        ref seeder: Seeder,
        dungeon_id: u128,
        parent_chamber_id: u32,
        new_chamber_id: u32,
        depth: u8,
        character_id: u128,
        revealed_by: u128,
        difficulty: u8,
        xp_earned: u32,
        current_max_depth: u8,
    ) {
        // ── Is this a boss chamber? ──────────────────────────────────────────
        let boss_prob: u32 = calculate_boss_probability(depth, xp_earned);
        let is_boss: bool = if boss_prob > 0 {
            let roll: u32 = roll_d20(ref seeder).into() * 500_u32; // scale 1-20 → 500-10000 bps
            roll <= boss_prob
        } else {
            false
        };

        // ── Generate chamber properties from seeder ──────────────────────────
        let (chamber_type, monster_type) = if is_boss {
            (ChamberType::Boss, MonsterType::Wraith)
        } else {
            // Pick chamber type using VRF
            // 0-2 → Monster (50%), 3 → Treasure (16%), 4 → Trap (16%), 5 → Empty (16%)
            let type_roll: u8 = seeder.random_u8() % 6;

            let ct: ChamberType =
                if type_roll <= 2 { ChamberType::Monster }
                else if type_roll == 3 { ChamberType::Treasure }
                else if type_roll == 4 { ChamberType::Trap }
                else { ChamberType::Empty };

            let mt: MonsterType = if ct == ChamberType::Monster {
                let random_val = seeder.random_u256();
                monster_for_depth(depth, difficulty, random_val)
            } else {
                MonsterType::None
            };
            (ct, mt)
        };

        // ── Exit count: 0-3 new exits (dead end = 0) ────────────────────────
        // At the frontier (depth >= current max), enforce at least 1 exit
        // so the dungeon always has a path forward.
        let raw_exit_count: u8 = seeder.random_u8() % 4;
        let exit_count: u8 = if raw_exit_count == 0 && depth >= current_max_depth {
            1
        } else {
            raw_exit_count
        };

        // ── Trap DC: 10 + depth/2 + (difficulty - 1)*2 ─────────────────────
        let trap_dc: u8 = if chamber_type == ChamberType::Trap {
            10_u8 + depth / 2 + (difficulty - 1) * 2
        } else {
            0
        };

        // ── Write Chamber model ──────────────────────────────────────────────
        world.write_model(@Chamber {
            dungeon_id,
            chamber_id: new_chamber_id,
            chamber_type,
            depth,
            exit_count,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc,
            fallen_count: 0,
        });

        // ── Write MonsterInstance if needed ──────────────────────────────────
        if monster_type != MonsterType::None {
            let stats = monster_type.get_stats();
            world.write_model(@MonsterInstance {
                dungeon_id,
                chamber_id: new_chamber_id,
                monster_id: 1,
                monster_type,
                current_hp: stats.hp.try_into().unwrap(),
                max_hp: stats.hp,
                is_alive: true,
            });
        }

        // ── Initialize exit stubs (undiscovered) ─────────────────────────────
        // These placeholders exist so open_exit can validate exit_index bounds.
        let mut i: u8 = 0;
        while i < exit_count {
            world.write_model(@ChamberExit {
                dungeon_id,
                from_chamber_id: new_chamber_id,
                exit_index: i,
                to_chamber_id: 0, // unknown until character opens it
                is_discovered: false,
            });
            i += 1;
        };

        // ── Update DungeonState: record boss chamber and max_depth ───────────
        // (next_chamber_id already incremented by caller before this call)
        if is_boss || depth > current_max_depth {
            let mut dungeon: DungeonState = world.read_model(dungeon_id);
            if is_boss {
                dungeon.boss_chamber_id = new_chamber_id;
            }
            if depth > current_max_depth {
                dungeon.max_depth = depth;
            }
            world.write_model(@dungeon);
        }

        // ── Emit ChamberRevealed event ───────────────────────────────────────
        world.emit_event(@ChamberRevealed {
            dungeon_id,
            chamber_id: new_chamber_id,
            chamber_type,
            depth,
            revealed_by,
        });
    }
}
