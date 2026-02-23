#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::character::{
        CharacterStats, CharacterHealth, CharacterPosition,
    };
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberExit,
        CharacterDungeonProgress
    };
    use d20::d20::types::index::{ChamberType};
    use d20::tests::tester::{
        setup_world, mint_fighter,
    };
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_mint_temple_creates_temple_state() {
        let caller: ContractAddress = 'templeowner1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, _token, _combat, temple) = setup_world();

        let dungeon_id = temple.mint_temple(1_u8);
        assert(dungeon_id != 0, 'dungeon_id must be non-zero');

        let state: DungeonState = world.read_model(dungeon_id);
        assert(state.difficulty_tier == 1, 'difficulty should be 1');
        assert(state.boss_alive, 'boss should start alive');
        assert(state.next_chamber_id == 2, 'next chamber starts at 2');
        assert(state.boss_chamber_id == 0, 'no boss chamber yet');
        assert(state.max_depth == 1, 'max_depth should be 1');

        // Verify entrance Chamber was created by mint_temple
        let entrance: Chamber = world.read_model((dungeon_id, 1_u32));
        assert(entrance.chamber_type == ChamberType::Entrance, 'entrance type');
        assert(entrance.depth == 1, 'entrance depth == 1');
        assert(entrance.exit_count == 3, 'entrance has 3 exits');
        assert(entrance.is_revealed, 'entrance is revealed');
        assert(!entrance.treasure_looted, 'entrance not looted');

        // Verify 3 undiscovered exit stubs
        let exit0: ChamberExit = world.read_model((dungeon_id, 1_u32, 0_u8));
        assert(!exit0.is_discovered, 'exit 0 undiscovered');
        assert(exit0.to_chamber_id == 0, 'exit 0 points nowhere');

        let exit1: ChamberExit = world.read_model((dungeon_id, 1_u32, 1_u8));
        assert(!exit1.is_discovered, 'exit 1 undiscovered');
        assert(exit1.to_chamber_id == 0, 'exit 1 points nowhere');

        let exit2: ChamberExit = world.read_model((dungeon_id, 1_u32, 2_u8));
        assert(!exit2.is_discovered, 'exit 2 undiscovered');
        assert(exit2.to_chamber_id == 0, 'exit 2 points nowhere');

        // Verify ERC721 state
        assert(temple.total_supply() == 1_u256, 'supply should be 1');
        assert(temple.balance_of(caller) == 1_u256, 'balance should be 1');
        assert(temple.owner_of(dungeon_id.into()) == caller, 'wrong owner');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_mint_temple_sequential_ids() {
        let caller: ContractAddress = 'templeowner2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, _token, _combat, temple) = setup_world();

        let id1 = temple.mint_temple(1_u8);
        let id2 = temple.mint_temple(2_u8);
        assert(id2 == id1 + 1, 'ids should be sequential');

        // Verify ERC721 state
        assert(temple.total_supply() == 2_u256, 'supply should be 2');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_mint_temple_rejects_zero_difficulty() {
        let caller: ContractAddress = 'templeowner3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, _token, _combat, temple) = setup_world();
        temple.mint_temple(0_u8);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_enter_temple_places_explorer_at_entrance() {
        let caller: ContractAddress = 'entertest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        temple.enter_temple(character_id, dungeon_id);

        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.dungeon_id == dungeon_id, 'in correct temple');
        assert(pos.chamber_id == 1, 'at entrance chamber');
        assert(!pos.in_combat, 'not in combat on entry');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_enter_temple_initializes_progress() {
        let caller: ContractAddress = 'entertest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        temple.enter_temple(character_id, dungeon_id);

        let progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));
        assert(progress.chambers_explored == 0, 'fresh progress');
        assert(progress.xp_earned == 0, 'no xp yet');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_enter_temple_rejects_dead_explorer() {
        let caller: ContractAddress = 'entertest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        temple.enter_temple(character_id, dungeon_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_exit_temple_clears_position() {
        let caller: ContractAddress = 'exittest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        temple.enter_temple(character_id, dungeon_id);
        temple.exit_temple(character_id);

        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.dungeon_id == 0, 'dungeon_id cleared');
        assert(pos.chamber_id == 0, 'chamber_id cleared');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_exit_temple_preserves_stats() {
        let caller: ContractAddress = 'exittest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        let stats_before: CharacterStats = world.read_model(character_id);

        temple.enter_temple(character_id, dungeon_id);
        temple.exit_temple(character_id);

        let stats_after: CharacterStats = world.read_model(character_id);
        assert(stats_after.level == stats_before.level, 'level preserved');
        assert(stats_after.xp == stats_before.xp, 'xp preserved');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_exit_temple_fails_not_in_temple() {
        let caller: ContractAddress = 'exittest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, _combat, temple) = setup_world();

        let character_id = mint_fighter(token);
        temple.exit_temple(character_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_exit_temple_fails_during_combat() {
        let caller: ContractAddress = 'exitcombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(character_id, dungeon_id);
        world.write_model_test(@CharacterPosition { character_id, dungeon_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });
        temple.exit_temple(character_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_enter_temple_rejects_explorer_in_combat() {
        let caller: ContractAddress = 'entertest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let character_id = mint_fighter(token);
        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        world.write_model_test(@CharacterPosition { character_id, dungeon_id: temple_a, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.enter_temple(character_id, temple_b);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_reenter_same_temple_preserves_progress() {
        let caller: ContractAddress = 'reenter1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let character_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        temple.enter_temple(character_id, dungeon_id);
        world.write_model_test(@CharacterDungeonProgress { character_id, dungeon_id, chambers_explored: 5, xp_earned: 200 });
        temple.exit_temple(character_id);
        temple.enter_temple(character_id, dungeon_id);

        let progress: CharacterDungeonProgress = world.read_model((character_id, dungeon_id));
        assert(progress.chambers_explored == 5, 'chambers preserved');
        assert(progress.xp_earned == 200, 'xp preserved');

        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.chamber_id == 1, 'at entrance on re-entry');
    }

}
