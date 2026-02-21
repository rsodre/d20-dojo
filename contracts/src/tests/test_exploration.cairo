#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::adventurer::{
        AdventurerHealth, AdventurerPosition,
    };
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberExit,
        AdventurerDungeonProgress
    };
    use d20::d20::types::index::{ChamberType};
    use d20::tests::tester::{
        setup_world, mint_fighter,
    };
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_open_exit_generates_new_chamber() {
        let caller: ContractAddress = 'opentest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        // Set up entrance chamber with 2 exits
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 2,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.open_exit(adventurer_id, 0);

        // A new chamber (id=2) should now exist
        let new_chamber: Chamber = world.read_model((dungeon_id, 2_u32));
        assert(new_chamber.is_revealed, 'new chamber should be revealed');
        assert(new_chamber.depth == 2, 'depth should be 2');

        // Exit should be marked discovered
        let exit: ChamberExit = world.read_model((dungeon_id, 1_u32, 0_u8));
        assert(exit.is_discovered, 'exit should be discovered');
        assert(exit.to_chamber_id == 2, 'exit points to new chamber');

        // DungeonState.max_depth should be updated to the new chamber's depth
        let state: DungeonState = world.read_model(dungeon_id);
        assert(state.max_depth == 2, 'max_depth should be 2');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_open_exit_increments_chambers_explored() {
        let caller: ContractAddress = 'opentest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 2,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.open_exit(adventurer_id, 0);

        let progress: AdventurerDungeonProgress = world.read_model((adventurer_id, dungeon_id));
        assert(progress.chambers_explored == 1, 'should have explored 1 chamber');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_open_exit_creates_back_exit() {
        let caller: ContractAddress = 'opentest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

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
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.open_exit(adventurer_id, 0);

        // Back exit from chamber 2 to chamber 1 should be discovered
        let back_exit: ChamberExit = world.read_model((dungeon_id, 2_u32, 0_u8));
        assert(back_exit.is_discovered, 'back exit should be discovered');
        assert(back_exit.to_chamber_id == 1, 'back exit points to entrance');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_already_discovered() {
        let caller: ContractAddress = 'opentest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

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
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.open_exit(adventurer_id, 0); // first time: ok
        temple.open_exit(adventurer_id, 0); // second time: should panic
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_open_exit_fails_with_invalid_index() {
        let caller: ContractAddress = 'opentest7'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { dungeon_id, chamber_id: 1, chamber_type: ChamberType::Entrance, depth: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.open_exit(adventurer_id, 5);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_dead() {
        let caller: ContractAddress = 'opentest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { dungeon_id, chamber_id: 1, chamber_type: ChamberType::Entrance, depth: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { dungeon_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 0, is_discovered: false });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });

        temple.open_exit(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_in_combat() {
        let caller: ContractAddress = 'opentest6'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { dungeon_id, chamber_id: 1, chamber_type: ChamberType::Entrance, depth: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { dungeon_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 0, is_discovered: false });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });

        temple.open_exit(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_move_to_empty_chamber_no_combat() {
        let caller: ContractAddress = 'movetest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        // Set up entrance with one discovered exit to an empty chamber
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
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 2,
            is_discovered: true,
        });
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 2,
            chamber_type: ChamberType::Empty,
            depth: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.move_to_chamber(adventurer_id, 0);

        let pos: AdventurerPosition = world.read_model(adventurer_id);
        assert(pos.chamber_id == 2, 'should be in chamber 2');
        assert(!pos.in_combat, 'no combat in empty chamber');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_move_to_undiscovered_exit_fails() {
        let caller: ContractAddress = 'movetest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

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
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false, // not yet discovered
        });

        temple.enter_temple(adventurer_id, dungeon_id);
        temple.move_to_chamber(adventurer_id, 0); // should panic
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_move_to_chamber_fails_if_dead() {
        let caller: ContractAddress = 'movetest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { dungeon_id, chamber_id: 1, chamber_type: ChamberType::Entrance, depth: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { dungeon_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { dungeon_id, chamber_id: 2, chamber_type: ChamberType::Empty, depth: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });

        temple.move_to_chamber(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_move_to_chamber_fails_if_in_combat() {
        let caller: ContractAddress = 'movetest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { dungeon_id, chamber_id: 1, chamber_type: ChamberType::Entrance, depth: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { dungeon_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });

        temple.move_to_chamber(adventurer_id, 0);
    }

}
