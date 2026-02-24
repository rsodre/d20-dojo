use dojo::world::WorldStorage;
use dojo::model::ModelStorage;
use d20::d20::models::dungeon::MonsterInstance;
use d20::d20::models::character::{CharacterPosition, CharacterCombat};
use d20::d20::models::monster::MonsterTypeTrait;
use d20::utils::dice::{roll_d20, roll_dice, ability_modifier};
use d20::utils::seeder::Seeder;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum SpellId {
    #[default]
    None,
    // Cantrips
    FireBolt,
    MageHand,
    Light,
    // 1st level
    MagicMissile,
    ShieldSpell,
    Sleep,
    // 2nd level
    ScorchingRay,
    MistyStep,
    // 3rd level
    Fireball,
}

#[generate_trait]
pub impl SpellImpl of SpellIdTrait {
    fn level(self: SpellId) -> u8 {
        match self {
            SpellId::None => 0,
            // Cantrips
            SpellId::FireBolt => 0,
            SpellId::MageHand => 0,
            SpellId::Light => 0,
            // 1st level
            SpellId::MagicMissile => 1,
            SpellId::ShieldSpell => 1,
            SpellId::Sleep => 1,
            // 2nd level
            SpellId::ScorchingRay => 2,
            SpellId::MistyStep => 2,
            // 3rd level
            SpellId::Fireball => 3,
        }
    }

    fn resolve(
        self: SpellId,
        ref world: WorldStorage,
        ref seeder: Seeder,
        character_id: u128,
        position: CharacterPosition,
        int_mod: i8,
        prof_bonus: u8,
    ) -> (u16, bool, u8, u32) {
        let mut damage_dealt: u16 = 0;
        let mut monster_killed: bool = false;
        let mut spell_roll: u8 = 0;
        let mut xp_to_award: u32 = 0;

        match self {
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
                        world.write_model(@CharacterPosition {
                            character_id,
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
                    world.write_model(@CharacterPosition {
                        character_id,
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
                let mut combat_state: CharacterCombat = world.read_model(character_id);
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
                    world.write_model(@CharacterPosition {
                        character_id,
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
                    world.write_model(@CharacterPosition {
                        character_id,
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
                    world.write_model(@CharacterPosition {
                        character_id,
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
                    world.write_model(@CharacterPosition {
                        character_id,
                        dungeon_id: position.dungeon_id,
                        chamber_id: position.chamber_id,
                        in_combat: false,
                        combat_monster_id: 0,
                    });
                }
            },
        }

        (damage_dealt, monster_killed, spell_roll, xp_to_award)
    }
}
