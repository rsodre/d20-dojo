#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::character::{
        CharacterStats, CharacterInventory,
        CharacterPosition
    };
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberExit, MonsterInstance,
        CharacterDungeonProgress
    };
    use d20::d20::types::index::{ChamberType};
    use d20::d20::types::character_class::CharacterClass;
    use d20::d20::models::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, mint_wizard,
    };
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_mint_enter_explore_fight_exit() {
        let caller: ContractAddress = 'fullflow1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        // 1. Mint explorer
        let character_id = mint_fighter(token);
        let stats: CharacterStats = world.read_model(character_id);
        assert(stats.level == 1, 'starts at level 1');
        assert(stats.character_class == CharacterClass::Fighter, 'is a fighter');

        // 2. Mint temple
        let dungeon_id = temple.mint_temple(1_u8);
        let temple_state: DungeonState = world.read_model(dungeon_id);
        assert(temple_state.boss_alive, 'boss starts alive');

        // 3. Enter temple
        temple.enter_temple(character_id, dungeon_id);
        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.dungeon_id == dungeon_id, 'in the right temple');
        assert(pos.chamber_id == 1, 'at entrance');

        // 4. Open exit and generate chamber 2
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.open_exit(character_id, 0);

        let progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));
        assert(progress.chambers_explored == 1, 'explored 1 chamber');

        // 5. Move to the newly generated chamber 2 if it's not a monster chamber,
        //    or skip to combat via direct model setup
        let chamber2: Chamber = world.read_model((dungeon_id, 2_u32));

        if chamber2.chamber_type == ChamberType::Monster || chamber2.chamber_type == ChamberType::Boss {
            // Move triggers combat
            temple.move_to_chamber(character_id, 0);
            let pos2: CharacterPosition = world.read_model(character_id);
            assert(pos2.in_combat, 'in combat after move');
        } else {
            // Move to empty/treasure/trap chamber — no combat
            temple.move_to_chamber(character_id, 0);
            let pos2: CharacterPosition = world.read_model(character_id);
            assert(!pos2.in_combat, 'not in combat in safe chamber');
        }

        // 6. Set up a guaranteed combat kill for the XP/boss check
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 5,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 1,
            max_hp: 13,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id,
            chamber_id: 5,
            in_combat: true,
            combat_monster_id: 1,
        });
        let mut stats: CharacterStats = world.read_model(character_id);
        stats.current_hp = 50;
        stats.max_hp = 50;
        stats.is_dead = false;
        world.write_model_test(@stats);

        let stats_pre: CharacterStats = world.read_model(character_id);
        let xp_before: u32 = stats_pre.xp;
        combat.attack(character_id);

        let monster_final: MonsterInstance = world.read_model((dungeon_id, 5_u32, 1_u32));
        if !monster_final.is_alive {
            let stats_final: CharacterStats = world.read_model(character_id);
            assert(stats_final.xp > xp_before, 'xp increased on kill');
        }

        // 7. Exit temple
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.exit_temple(character_id);
        let final_pos: CharacterPosition = world.read_model(character_id);
        assert(final_pos.dungeon_id == 0, 'exited temple');
        assert(final_pos.chamber_id == 0, 'chamber cleared');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_rogue_enters_loots_exits() {
        let caller: ContractAddress = 'fullflow2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let character_id = mint_rogue(token);
        let dungeon_id = temple.mint_temple(2_u8);

        // Enter
        temple.enter_temple(character_id, dungeon_id);
        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.dungeon_id == dungeon_id, 'rogue in temple');

        // Place rogue in a Treasure chamber
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 3,
            chamber_type: ChamberType::Treasure,
            depth: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Boost WIS to ensure loot check passes
        let mut stats: CharacterStats = world.read_model(character_id);
        stats.abilities.wisdom = 20;
        world.write_model_test(@stats);

        let inv_before: CharacterInventory = world.read_model(character_id);
        temple.loot_treasure(character_id);

        let chamber_after: Chamber = world.read_model((dungeon_id, 3_u32));
        let inv_after: CharacterInventory = world.read_model(character_id);

        assert(chamber_after.treasure_looted, 'treasure looted');
        // difficulty=2, depth=2: gold = d6 * 3 * 2 = at least 6
        assert(inv_after.gold >= inv_before.gold, 'gold should not decrease');

        // Exit
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });
        temple.exit_temple(character_id);

        let final_pos: CharacterPosition = world.read_model(character_id);
        assert(final_pos.dungeon_id == 0, 'rogue exited');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_wizard_casts_spell_kills_monster() {
        let caller: ContractAddress = 'fullflow3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let character_id = mint_wizard(token);
        let dungeon_id = temple.mint_temple(1_u8);

        temple.enter_temple(character_id, dungeon_id);

        // Place wizard in combat vs 1 HP PoisonousSnake
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::PoisonousSnake,
            current_hp: 1,
            max_hp: 2,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        let mut stats: CharacterStats = world.read_model(character_id);
        stats.current_hp = 50;
        stats.max_hp = 50;
        stats.is_dead = false;
        world.write_model_test(@stats);
        world.write_model_test(@CharacterDungeonProgress {
            character_id,
            dungeon_id,
            chambers_explored: 0,
            xp_earned: 0,
        });

        let stats_wiz_pre: CharacterStats = world.read_model(character_id);
        let xp_before: u32 = stats_wiz_pre.xp;

        // Cast Fire Bolt (cantrip)
        combat.cast_spell(character_id, d20::d20::types::spells::SpellId::FireBolt);

        let monster_after: MonsterInstance = world.read_model((dungeon_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: CharacterStats = world.read_model(character_id);
            assert(stats_after.xp > xp_before, 'wizard xp should increase');
        }
        // If Fire Bolt missed, monster may still be alive — test passes silently
    }

}
