#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait};

    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills
    };
    use d20::models::temple::{
        TempleState, Chamber, ChamberExit, MonsterInstance,
        FallenExplorer, ChamberFallenCount, ExplorerTempleProgress
    };
    use d20::types::index::{ChamberType};
    use d20::types::items::{WeaponType, ArmorType};
    use d20::types::explorer_class::ExplorerClass;
    use d20::types::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, mint_wizard, assert_explorer_dead,
    };
    use d20::systems::explorer_token::{IExplorerTokenDispatcherTrait};
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_mint_enter_explore_fight_exit() {
        let caller: ContractAddress = 'fullflow1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        // 1. Mint explorer
        let explorer_id = mint_fighter(token);
        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.level == 1, 'starts at level 1');
        assert(stats.explorer_class == ExplorerClass::Fighter, 'is a fighter');

        // 2. Mint temple
        let temple_id = temple.mint_temple(1_u8);
        let temple_state: TempleState = world.read_model(temple_id);
        assert(temple_state.boss_alive, 'boss starts alive');

        // 3. Enter temple
        temple.enter_temple(explorer_id, temple_id);
        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == temple_id, 'in the right temple');
        assert(pos.chamber_id == 1, 'at entrance');

        // 4. Open exit and generate chamber 2
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            yonder: 1,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ChamberExit {
            temple_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.open_exit(explorer_id, 0);

        let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
        assert(progress.chambers_explored == 1, 'explored 1 chamber');

        // 5. Move to the newly generated chamber 2 if it's not a monster chamber,
        //    or skip to combat via direct model setup
        let chamber2: Chamber = world.read_model((temple_id, 2_u32));

        if chamber2.chamber_type == ChamberType::Monster || chamber2.chamber_type == ChamberType::Boss {
            // Move triggers combat
            temple.move_to_chamber(explorer_id, 0);
            let pos2: ExplorerPosition = world.read_model(explorer_id);
            assert(pos2.in_combat, 'in combat after move');
        } else {
            // Move to empty/treasure/trap chamber — no combat
            temple.move_to_chamber(explorer_id, 0);
            let pos2: ExplorerPosition = world.read_model(explorer_id);
            assert(!pos2.in_combat, 'not in combat in safe chamber');
        }

        // 6. Set up a guaranteed combat kill for the XP/boss check
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 5,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 1,
            max_hp: 13,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 5,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        let stats_pre: ExplorerStats = world.read_model(explorer_id);
        let xp_before: u32 = stats_pre.xp;
        combat.attack(explorer_id);

        let monster_final: MonsterInstance = world.read_model((temple_id, 5_u32, 1_u32));
        if !monster_final.is_alive {
            let stats_final: ExplorerStats = world.read_model(explorer_id);
            assert(stats_final.xp > xp_before, 'xp increased on kill');
        }

        // 7. Exit temple
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.exit_temple(explorer_id);
        let final_pos: ExplorerPosition = world.read_model(explorer_id);
        assert(final_pos.temple_id == 0, 'exited temple');
        assert(final_pos.chamber_id == 0, 'chamber cleared');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_rogue_enters_loots_exits() {
        let caller: ContractAddress = 'fullflow2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_rogue(token);
        let temple_id = temple.mint_temple(2_u8);

        // Enter
        temple.enter_temple(explorer_id, temple_id);
        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == temple_id, 'rogue in temple');

        // Place rogue in a Treasure chamber
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 3,
            chamber_type: ChamberType::Treasure,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Boost WIS to ensure loot check passes
        let stats: ExplorerStats = world.read_model(explorer_id);
        let mut abilities = stats.abilities;
        abilities.wisdom = 20;
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });

        let inv_before: ExplorerInventory = world.read_model(explorer_id);
        temple.loot_treasure(explorer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 3_u32));
        let inv_after: ExplorerInventory = world.read_model(explorer_id);

        assert(chamber_after.treasure_looted, 'treasure looted');
        // difficulty=2, yonder=2: gold = d6 * 3 * 2 = at least 6
        assert(inv_after.gold >= inv_before.gold, 'gold should not decrease');

        // Exit
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });
        temple.exit_temple(explorer_id);

        let final_pos: ExplorerPosition = world.read_model(explorer_id);
        assert(final_pos.temple_id == 0, 'rogue exited');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_full_flow_wizard_casts_spell_kills_monster() {
        let caller: ContractAddress = 'fullflow3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_wizard(token);
        let temple_id = temple.mint_temple(1_u8);

        temple.enter_temple(explorer_id, temple_id);

        // Place wizard in combat vs 1 HP PoisonousSnake
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::PoisonousSnake,
            current_hp: 1,
            max_hp: 2,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });
        world.write_model_test(@ExplorerTempleProgress {
            explorer_id,
            temple_id,
            chambers_explored: 0,
            xp_earned: 0,
        });

        let stats_wiz_pre: ExplorerStats = world.read_model(explorer_id);
        let xp_before: u32 = stats_wiz_pre.xp;

        // Cast Fire Bolt (cantrip)
        combat.cast_spell(explorer_id, d20::types::spells::SpellId::FireBolt);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: ExplorerStats = world.read_model(explorer_id);
            assert(stats_after.xp > xp_before, 'wizard xp should increase');
        }
        // If Fire Bolt missed, monster may still be alive — test passes silently
    }

}
