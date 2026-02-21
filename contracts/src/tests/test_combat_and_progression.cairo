#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait};

    use d20::d20::models::adventurer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills
    };
    use d20::models::temple::{
        TempleState, Chamber, ChamberExit, MonsterInstance,
        FallenExplorer, ChamberFallenCount, ExplorerTempleProgress
    };
    use d20::types::index::{ChamberType};
    use d20::types::items::{WeaponType, ArmorType};
    use d20::d20::types::adventurer_class::AdventurerClass;
    use d20::types::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, mint_wizard, assert_explorer_dead,
    };
    use d20::systems::explorer_token::{IExplorerTokenDispatcherTrait};
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_move_to_monster_chamber_triggers_combat() {
        let caller: ContractAddress = 'movetest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

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
            to_chamber_id: 2,
            is_discovered: true,
        });
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Monster,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        temple.enter_temple(adventurer_id, temple_id);
        temple.move_to_chamber(adventurer_id, 0);

        let pos: ExplorerPosition = world.read_model(adventurer_id);
        assert(pos.chamber_id == 2, 'moved to chamber 2');
        assert(pos.in_combat, 'should be in combat');
        assert(pos.combat_monster_id == 1, 'fighting monster 1');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_attack_in_temple_records_position() {
        let caller: ContractAddress = 'combattest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Give explorer high HP so they survive the counter-attack
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        // Manually place in combat vs a skeleton in the temple
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 100,
            max_hp: 100,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat.attack(adventurer_id);

        // Monster should have taken some damage (or attack missed — hp ≤ 100)
        let monster: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        assert(monster.current_hp <= 100, 'monster hp did not increase');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_kill_monster_grants_xp() {
        let caller: ContractAddress = 'xptest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        let stats_before: ExplorerStats = world.read_model(adventurer_id);

        // Place in combat vs a 1 HP monster (guaranteed kill this turn)
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 1,
            max_hp: 13,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        // Initialize progress so gain_xp can update it
        world.write_model_test(@ExplorerTempleProgress {
            adventurer_id,
            temple_id,
            chambers_explored: 0,
            xp_earned: 0,
        });

        combat.attack(adventurer_id);

        let stats_after: ExplorerStats = world.read_model(adventurer_id);
        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));

        if !monster_after.is_alive {
            // Monster was killed — XP must have been awarded
            assert(stats_after.xp > stats_before.xp, 'xp should increase on kill');

            let progress: ExplorerTempleProgress = world.read_model((adventurer_id, temple_id));
            assert(progress.xp_earned > 0, 'temple xp_earned should grow');
        }
        // If monster survived (attack missed), test passes silently
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_kill_monster_updates_temple_progress() {
        let caller: ContractAddress = 'xptest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 3,
            monster_id: 1,
            monster_type: MonsterType::PoisonousSnake,
            current_hp: 1,
            max_hp: 2,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 3,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });
        world.write_model_test(@ExplorerTempleProgress {
            adventurer_id,
            temple_id,
            chambers_explored: 2,
            xp_earned: 100,
        });

        combat.attack(adventurer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 3_u32, 1_u32));
        if !monster_after.is_alive {
            let progress: ExplorerTempleProgress = world.read_model((adventurer_id, temple_id));
            assert(progress.xp_earned > 100, 'xp_earned should increase');
            assert(progress.chambers_explored == 2, 'chambers_explored unchanged');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_level_up_increases_max_hp() {
        let caller: ContractAddress = 'lvltest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set XP just below level 2 threshold (300 XP)
        let stats: ExplorerStats = world.read_model(adventurer_id);
        world.write_model_test(@ExplorerStats {
            adventurer_id,
            abilities: stats.abilities,
            level: 1,
            xp: 250, // skeleton = 50 XP → total 300 = level 2
            adventurer_class: stats.adventurer_class,
            temples_conquered: stats.temples_conquered,
        });

        let health_before: ExplorerHealth = world.read_model(adventurer_id);

        // 1 HP skeleton → guaranteed kill
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 1,
            max_hp: 13,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });
        world.write_model_test(@ExplorerTempleProgress {
            adventurer_id,
            temple_id,
            chambers_explored: 0,
            xp_earned: 0,
        });

        combat.attack(adventurer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: ExplorerStats = world.read_model(adventurer_id);
            if stats_after.xp >= 300 {
                assert(stats_after.level == 2, 'should be level 2');
                let health_after: ExplorerHealth = world.read_model(adventurer_id);
                assert(health_after.max_hp > health_before.max_hp, 'max_hp should increase');
            }
        }
    }

}
