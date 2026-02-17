use d20::types::SpellId;
use d20::types::ItemType;

// ── Public interface ────────────────────────────────────────────────────────

#[starknet::interface]
pub trait ICombatSystem<TState> {
    /// Attack the monster the explorer is currently in combat with.
    /// Rolls attack (d20 + STR mod + proficiency) vs monster AC.
    /// On hit, rolls weapon damage. Emits CombatResult event.
    fn attack(ref self: TState, explorer_id: u128);

    /// Cast a spell (task 2.8 — stub for now).
    fn cast_spell(ref self: TState, explorer_id: u128, spell_id: SpellId);

    /// Use an item (task 2.8 — stub for now).
    fn use_item(ref self: TState, explorer_id: u128, item_type: ItemType);

    /// Flee from combat (task 2.10 — stub for now).
    fn flee(ref self: TState, explorer_id: u128);

    /// Fighter: Second Wind (task 2.6 — stub for now).
    fn second_wind(ref self: TState, explorer_id: u128);

    /// Rogue: Cunning Action (task 2.7 — stub for now).
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
        ExplorerStats, ExplorerHealth, ExplorerInventory, ExplorerPosition,
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
                WeaponType::Longsword => 8,   // 1d8
                WeaponType::Dagger => 4,      // 1d4
                WeaponType::Shortbow => 6,    // 1d6
                WeaponType::Greataxe => 12,   // 1d12
                WeaponType::Staff => 6,       // 1d6
                WeaponType::None => 4,        // fallback
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
        /// Dagger and Shortbow use DEX; melee weapons use STR.
        fn weapon_uses_dex(weapon: WeaponType) -> bool {
            match weapon {
                WeaponType::Dagger => true,
                WeaponType::Shortbow => true,
                _ => false,
            }
        }

        /// Handle explorer death: set is_dead, emit ExplorerDied.
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

            // Clear combat state
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

            // Load monster instance
            let mut monster: MonsterInstance = world.read_model(
                (position.temple_id, position.chamber_id, position.combat_monster_id)
            );
            assert(monster.is_alive, 'monster is already dead');

            // Look up static monster stats for AC
            let monster_stats = get_monster_stats(monster.monster_type);

            // ── Attack roll ─────────────────────────────────────────────────
            // Attack = d20 + ability_modifier + proficiency_bonus >= monster AC

            let weapon = inventory.primary_weapon;
            let uses_dex = InternalImpl::weapon_uses_dex(weapon);

            let ability_score: u8 = if uses_dex {
                stats.dexterity
            } else {
                stats.strength
            };
            let ability_mod: i8 = ability_modifier(ability_score);
            let prof_bonus: u8 = proficiency_bonus(stats.level);

            let attack_roll: u8 = roll_d20(caller);

            // Natural 1 = auto-miss, natural 20 = critical hit
            let is_nat_1: bool = attack_roll == 1;
            let is_nat_20: bool = attack_roll == 20;

            // Total attack = roll + ability mod + proficiency (cast to i16 for signed math)
            let total_attack: i16 = attack_roll.into()
                + ability_mod.into()
                + prof_bonus.into();

            let hits: bool = !is_nat_1 && (is_nat_20 || total_attack >= monster_stats.ac.into());

            let mut damage_dealt: u16 = 0;
            let mut monster_killed: bool = false;

            if hits {
                // ── Damage roll ─────────────────────────────────────────────
                let dice_sides: u8 = InternalImpl::weapon_damage_sides(weapon);
                let dice_count: u8 = if is_nat_20 {
                    // Critical hit: double the damage dice
                    InternalImpl::weapon_damage_count(weapon) * 2
                } else {
                    InternalImpl::weapon_damage_count(weapon)
                };

                let raw_damage: u16 = roll_dice(caller, dice_sides, dice_count);

                // Add ability modifier to damage (can be negative for low STR/DEX)
                // u16 -> i16: cast via i32 to handle both raw_damage (u16) and ability_mod (i8)
                let raw_damage_i32: i32 = raw_damage.into();
                let ability_mod_i32: i32 = ability_mod.into();
                let damage_i32: i32 = raw_damage_i32 + ability_mod_i32;
                let damage_with_mod: i16 = damage_i32.try_into().unwrap();
                // Minimum 1 damage on a hit
                damage_dealt = if damage_with_mod < 1 {
                    1
                } else {
                    damage_with_mod.try_into().unwrap()
                };

                // Deduct HP from monster
                let new_monster_hp: i16 = monster.current_hp - damage_dealt.try_into().unwrap();
                monster_killed = new_monster_hp <= 0;

                if monster_killed {
                    world.write_model(@MonsterInstance {
                        temple_id: position.temple_id,
                        chamber_id: position.chamber_id,
                        monster_id: position.combat_monster_id,
                        monster_type: monster.monster_type,
                        current_hp: new_monster_hp,
                        max_hp: monster.max_hp,
                        is_alive: false,
                    });

                    // Exit combat
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
                        current_hp: new_monster_hp,
                        max_hp: monster.max_hp,
                        is_alive: true,
                    });
                }
            }

            // ── Monster counter-attack (task 2.5 placeholder) ────────────────
            // Skipped here — implemented in task 2.5.
            // damage_taken stays 0 until monster turn is implemented.
            let damage_taken: u16 = 0;

            // ── Emit CombatResult ────────────────────────────────────────────
            world.emit_event(@CombatResult {
                explorer_id,
                action: CombatAction::Attack,
                roll: attack_roll,
                damage_dealt,
                damage_taken,
                monster_killed,
            });
        }

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

        fn second_wind(ref self: ContractState, explorer_id: u128) {
            // Implemented in task 2.6
            assert(false, 'not implemented');
        }

        fn cunning_action(ref self: ContractState, explorer_id: u128) {
            // Implemented in task 2.7
            assert(false, 'not implemented');
        }
    }
}
