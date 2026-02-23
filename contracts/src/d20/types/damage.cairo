use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use dojo::world::WorldStorage;
use d20::d20::models::character::{CharacterHealth, CharacterPosition, CharacterInventory};
use d20::d20::models::dungeon::{FallenCharacter, ChamberFallenCount};
use d20::d20::models::events::CharacterDied;
use d20::d20::models::monster::MonsterType;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DamageType {
    #[default]
    None,
    Slashing,
    Piercing,
    Bludgeoning,
    Fire,
    Cold,
    Lightning,
    Force,
    Necrotic,
}

pub trait DamageTrait {
    fn apply_character_damage(
        ref world: WorldStorage,
        character_id: u128,
        health: CharacterHealth,
        position: CharacterPosition,
        monster_type: MonsterType,
        damage: u16,
    ) -> u16;

    fn handle_death(
        ref world: WorldStorage,
        character_id: u128,
        health: CharacterHealth,
        position: CharacterPosition,
        monster_type: MonsterType,
    );
}

pub impl DamageImpl of DamageTrait {
    /// Apply damage to the character. Returns actual damage taken.
    /// If HP drops to ≤0, calls handle_death.
    fn apply_character_damage(
        ref world: WorldStorage,
        character_id: u128,
        health: CharacterHealth,
        position: CharacterPosition,
        monster_type: MonsterType,
        damage: u16,
    ) -> u16 {
        let damage_i16: i16 = damage.try_into().unwrap();
        let new_hp: i16 = health.current_hp - damage_i16;

        if new_hp <= 0 {
            Self::handle_death(ref world, character_id, health, position, monster_type);
            // Return actual HP lost (capped at what the character had)
            health.current_hp.try_into().unwrap()
        } else {
            world.write_model(@CharacterHealth {
                character_id,
                current_hp: new_hp,
                max_hp: health.max_hp,
                is_dead: false,
            });
            damage
        }
    }

    /// Handle explorer death:
    ///   1. Set is_dead on CharacterHealth, clear HP to 0.
    ///   2. Clear combat state on CharacterPosition.
    ///   3. Read inventory and create FallenCharacter with dropped loot.
    ///   4. Increment ChamberFallenCount.
    ///   5. Zero out inventory (items are now on the ground).
    ///   6. Emit CharacterDied event.
    fn handle_death(
        ref world: WorldStorage,
        character_id: u128,
        health: CharacterHealth,
        position: CharacterPosition,
        monster_type: MonsterType,
    ) {
        // 1. Mark explorer dead
        world.write_model(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: health.max_hp,
            is_dead: true,
        });

        // 2. Clear combat state
        world.write_model(@CharacterPosition {
            character_id,
            dungeon_id: position.dungeon_id,
            chamber_id: position.chamber_id,
            in_combat: false,
            combat_monster_id: 0,
        });

        // 3. Read inventory for loot drop
        let inventory: CharacterInventory = world.read_model(character_id);

        // 4. Determine fallen_index from ChamberFallenCount (read-then-increment)
        let fallen_count: ChamberFallenCount = world.read_model(
            (position.dungeon_id, position.chamber_id)
        );
        let fallen_index: u32 = fallen_count.count;

        // 5. Create FallenCharacter loot record
        world.write_model(@FallenCharacter {
            dungeon_id: position.dungeon_id,
            chamber_id: position.chamber_id,
            fallen_index,
            character_id,
            dropped_weapon: inventory.primary_weapon,
            dropped_armor: inventory.armor,
            dropped_gold: inventory.gold,
            dropped_potions: inventory.potions,
            is_looted: false,
        });

        // 6. Increment ChamberFallenCount
        world.write_model(@ChamberFallenCount {
            dungeon_id: position.dungeon_id,
            chamber_id: position.chamber_id,
            count: fallen_count.count + 1,
        });

        // 7. Zero out explorer inventory (loot is now on the ground)
        world.write_model(@CharacterInventory {
            character_id,
            primary_weapon: inventory.primary_weapon,
            secondary_weapon: inventory.secondary_weapon,
            armor: inventory.armor,
            has_shield: inventory.has_shield,
            gold: 0,
            potions: 0,
        });

        // 8. Emit CharacterDied event
        world.emit_event(@CharacterDied {
            character_id,
            dungeon_id: position.dungeon_id,
            chamber_id: position.chamber_id,
            killed_by: monster_type,
        });
    }
}
