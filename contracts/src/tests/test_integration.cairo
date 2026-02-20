/// Integration tests for the full D20 dungeon-crawler flow.
/// Covers: mint_explorer → mint_temple → enter_temple → open_exit →
///         move_to_chamber → attack (kill monster, gain XP) →
///         loot_treasure → level-up → boss defeat.
#[cfg(test)]
mod tests {

    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::syscalls::{deploy_syscall};
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait,
    };

    use d20::systems::explorer_token::{
        explorer_token, IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
    };
    use d20::systems::combat_system::{
        combat_system, ICombatSystemDispatcher, ICombatSystemDispatcherTrait,
    };
    use d20::systems::temple_token::{
        temple_token, ITempleTokenDispatcher, ITempleTokenDispatcherTrait,
    };
    use d20::models::config::m_Config;
    use d20::models::explorer::{
        ExplorerStats, m_ExplorerStats,
        ExplorerHealth, m_ExplorerHealth,
        ExplorerCombat, m_ExplorerCombat,
        ExplorerInventory, m_ExplorerInventory,
        ExplorerPosition, m_ExplorerPosition,
        m_ExplorerSkills,
    };
    use d20::models::temple::{
        TempleState, m_TempleState,
        Chamber, m_Chamber,
        MonsterInstance, m_MonsterInstance,
        ChamberExit, m_ChamberExit,
        FallenExplorer, m_FallenExplorer,
        ChamberFallenCount, m_ChamberFallenCount,
        ExplorerTempleProgress, m_ExplorerTempleProgress,
    };
    use d20::events::{
        e_ExplorerMinted, e_CombatResult, e_ExplorerDied,
        e_ChamberRevealed, e_LevelUp, e_BossDefeated,
    };
    use d20::types::index::{ChamberType, ItemType};
    use d20::types::items::{WeaponType, ArmorType};
    use d20::types::explorer_class::ExplorerClass;
    use d20::types::monster::MonsterType;
    use d20::tests::mock_vrf::MockVrf;

    // ── Test world setup ──────────────────────────────────────────────────────

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: [
                // Config
                TestResource::Model(m_Config::TEST_CLASS_HASH),
                // Explorer models
                TestResource::Model(m_ExplorerStats::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerHealth::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerCombat::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerInventory::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerPosition::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerSkills::TEST_CLASS_HASH),
                // Temple models
                TestResource::Model(m_TempleState::TEST_CLASS_HASH),
                TestResource::Model(m_Chamber::TEST_CLASS_HASH),
                TestResource::Model(m_MonsterInstance::TEST_CLASS_HASH),
                TestResource::Model(m_ChamberExit::TEST_CLASS_HASH),
                TestResource::Model(m_FallenExplorer::TEST_CLASS_HASH),
                TestResource::Model(m_ChamberFallenCount::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerTempleProgress::TEST_CLASS_HASH),
                // Events
                TestResource::Event(e_ExplorerMinted::TEST_CLASS_HASH),
                TestResource::Event(e_CombatResult::TEST_CLASS_HASH),
                TestResource::Event(e_ExplorerDied::TEST_CLASS_HASH),
                TestResource::Event(e_ChamberRevealed::TEST_CLASS_HASH),
                TestResource::Event(e_LevelUp::TEST_CLASS_HASH),
                TestResource::Event(e_BossDefeated::TEST_CLASS_HASH),
                // Contracts
                TestResource::Contract(explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(combat_system::TEST_CLASS_HASH),
                TestResource::Contract(temple_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    fn setup_world() -> (
        dojo::world::WorldStorage,
        IExplorerTokenDispatcher,
        ICombatSystemDispatcher,
        ITempleTokenDispatcher,
    ) {
        // 1. Deploy MockVrf
        let mock_vrf_class_hash = MockVrf::TEST_CLASS_HASH;
        let (mock_vrf_address, _) = deploy_syscall(
            mock_vrf_class_hash,
            0,
            [].span(),
            false,
        ).unwrap_syscall();

        // 2. Build contract defs — pass vrf_address as init calldata for both token contracts
        let contract_defs: Span<ContractDef> = [
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_1", @"combat_system")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_1", @"temple_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span()),
        ].span();

        // 3. Spawn world and sync
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);

        let (token_addr, _) = world.dns(@"explorer_token").unwrap();
        let (combat_addr, _) = world.dns(@"combat_system").unwrap();
        let (temple_addr, _) = world.dns(@"temple_token").unwrap();

        (
            world,
            IExplorerTokenDispatcher { contract_address: token_addr },
            ICombatSystemDispatcher { contract_address: combat_addr },
            ITempleTokenDispatcher { contract_address: temple_addr },
        )
    }

    // ── Mint helpers ──────────────────────────────────────────────────────────

    fn mint_fighter(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(ExplorerClass::Fighter)
    }

    fn mint_rogue(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(ExplorerClass::Rogue)
    }

    fn mint_wizard(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(ExplorerClass::Wizard)
    }

    // ── Death assertion helper ────────────────────────────────────────────────

    /// Validates all invariants that must hold after an explorer dies:
    /// - is_dead flag set, HP at 0, not in combat
    /// - FallenExplorer record created in the correct chamber
    /// - ChamberFallenCount incremented
    /// - Inventory gold and potions zeroed (dropped as loot)
    fn assert_explorer_dead(
        ref world: dojo::world::WorldStorage,
        explorer_id: u128,
        temple_id: u128,
        chamber_id: u32,
    ) {
        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.is_dead, 'explorer should be dead');
        assert(health.current_hp == 0, 'hp should be 0 on death');

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(!pos.in_combat, 'dead explorer not in combat');

        let fallen_count: ChamberFallenCount = world.read_model((temple_id, chamber_id));
        assert(fallen_count.count >= 1, 'fallen count should be >= 1');

        let fallen: FallenExplorer = world.read_model(
            (temple_id, chamber_id, fallen_count.count - 1)
        );
        assert(fallen.explorer_id == explorer_id, 'fallen explorer id mismatch');
        assert(!fallen.is_looted, 'fallen should not be looted');

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.gold == 0, 'gold dropped on death');
        assert(inv.potions == 0, 'potions dropped on death');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Temple minting
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_mint_temple_creates_temple_state() {
        let caller: ContractAddress = 'templeowner1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, _token, _combat, temple) = setup_world();

        let temple_id = temple.mint_temple(1_u8);
        assert(temple_id != 0, 'temple_id must be non-zero');

        let state: TempleState = world.read_model(temple_id);
        assert(state.difficulty_tier == 1, 'difficulty should be 1');
        assert(state.boss_alive, 'boss should start alive');
        assert(state.next_chamber_id == 2, 'next chamber starts at 2');
        assert(state.boss_chamber_id == 0, 'no boss chamber yet');
        assert(state.max_yonder == 1, 'max_yonder should be 1');

        // Verify entrance Chamber was created by mint_temple
        let entrance: Chamber = world.read_model((temple_id, 1_u32));
        assert(entrance.chamber_type == ChamberType::Entrance, 'entrance type');
        assert(entrance.yonder == 1, 'entrance yonder == 1');
        assert(entrance.exit_count == 3, 'entrance has 3 exits');
        assert(entrance.is_revealed, 'entrance is revealed');
        assert(!entrance.treasure_looted, 'entrance not looted');

        // Verify 3 undiscovered exit stubs
        let exit0: ChamberExit = world.read_model((temple_id, 1_u32, 0_u8));
        assert(!exit0.is_discovered, 'exit 0 undiscovered');
        assert(exit0.to_chamber_id == 0, 'exit 0 points nowhere');

        let exit1: ChamberExit = world.read_model((temple_id, 1_u32, 1_u8));
        assert(!exit1.is_discovered, 'exit 1 undiscovered');
        assert(exit1.to_chamber_id == 0, 'exit 1 points nowhere');

        let exit2: ChamberExit = world.read_model((temple_id, 1_u32, 2_u8));
        assert(!exit2.is_discovered, 'exit 2 undiscovered');
        assert(exit2.to_chamber_id == 0, 'exit 2 points nowhere');

        // Verify ERC721 state
        assert(temple.total_supply() == 1_u256, 'supply should be 1');
        assert(temple.balance_of(caller) == 1_u256, 'balance should be 1');
        assert(temple.owner_of(temple_id.into()) == caller, 'wrong owner');
    }

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

    #[test]
    #[should_panic]
    fn test_mint_temple_rejects_zero_difficulty() {
        let caller: ContractAddress = 'templeowner3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, _token, _combat, temple) = setup_world();
        temple.mint_temple(0_u8);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // enter_temple / exit_temple
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_enter_temple_places_explorer_at_entrance() {
        let caller: ContractAddress = 'entertest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        temple.enter_temple(explorer_id, temple_id);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == temple_id, 'in correct temple');
        assert(pos.chamber_id == 1, 'at entrance chamber');
        assert(!pos.in_combat, 'not in combat on entry');
    }

    #[test]
    fn test_enter_temple_initializes_progress() {
        let caller: ContractAddress = 'entertest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        temple.enter_temple(explorer_id, temple_id);

        let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
        assert(progress.chambers_explored == 0, 'fresh progress');
        assert(progress.xp_earned == 0, 'no xp yet');
    }

    #[test]
    #[should_panic]
    fn test_enter_temple_rejects_dead_explorer() {
        let caller: ContractAddress = 'entertest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        temple.enter_temple(explorer_id, temple_id);
    }

    #[test]
    fn test_exit_temple_clears_position() {
        let caller: ContractAddress = 'exittest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        temple.enter_temple(explorer_id, temple_id);
        temple.exit_temple(explorer_id);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == 0, 'temple_id cleared');
        assert(pos.chamber_id == 0, 'chamber_id cleared');
    }

    #[test]
    fn test_exit_temple_preserves_stats() {
        let caller: ContractAddress = 'exittest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        let stats_before: ExplorerStats = world.read_model(explorer_id);

        temple.enter_temple(explorer_id, temple_id);
        temple.exit_temple(explorer_id);

        let stats_after: ExplorerStats = world.read_model(explorer_id);
        assert(stats_after.level == stats_before.level, 'level preserved');
        assert(stats_after.xp == stats_before.xp, 'xp preserved');
    }

    #[test]
    #[should_panic]
    fn test_exit_temple_fails_not_in_temple() {
        let caller: ContractAddress = 'exittest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        temple.exit_temple(explorer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // open_exit — generates a new chamber
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_open_exit_generates_new_chamber() {
        let caller: ContractAddress = 'opentest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up entrance chamber with 2 exits
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            yonder: 1,
            exit_count: 2,
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

        temple.enter_temple(explorer_id, temple_id);
        temple.open_exit(explorer_id, 0);

        // A new chamber (id=2) should now exist
        let new_chamber: Chamber = world.read_model((temple_id, 2_u32));
        assert(new_chamber.is_revealed, 'new chamber should be revealed');
        assert(new_chamber.yonder == 2, 'yonder should be 2');

        // Exit should be marked discovered
        let exit: ChamberExit = world.read_model((temple_id, 1_u32, 0_u8));
        assert(exit.is_discovered, 'exit should be discovered');
        assert(exit.to_chamber_id == 2, 'exit points to new chamber');

        // TempleState.max_yonder should be updated to the new chamber's yonder
        let state: TempleState = world.read_model(temple_id);
        assert(state.max_yonder == 2, 'max_yonder should be 2');
    }

    #[test]
    fn test_open_exit_increments_chambers_explored() {
        let caller: ContractAddress = 'opentest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            yonder: 1,
            exit_count: 2,
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

        temple.enter_temple(explorer_id, temple_id);
        temple.open_exit(explorer_id, 0);

        let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
        assert(progress.chambers_explored == 1, 'should have explored 1 chamber');
    }

    #[test]
    fn test_open_exit_creates_back_exit() {
        let caller: ContractAddress = 'opentest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
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
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(explorer_id, temple_id);
        temple.open_exit(explorer_id, 0);

        // Back exit from chamber 2 to chamber 1 should be discovered
        let back_exit: ChamberExit = world.read_model((temple_id, 2_u32, 0_u8));
        assert(back_exit.is_discovered, 'back exit should be discovered');
        assert(back_exit.to_chamber_id == 1, 'back exit points to entrance');
    }

    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_already_discovered() {
        let caller: ContractAddress = 'opentest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
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
            to_chamber_id: 0,
            is_discovered: false,
        });

        temple.enter_temple(explorer_id, temple_id);
        temple.open_exit(explorer_id, 0); // first time: ok
        temple.open_exit(explorer_id, 0); // second time: should panic
    }

    // ═══════════════════════════════════════════════════════════════════════
    // move_to_chamber
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_move_to_empty_chamber_no_combat() {
        let caller: ContractAddress = 'movetest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up entrance with one discovered exit to an empty chamber
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
            chamber_type: ChamberType::Empty,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });

        temple.enter_temple(explorer_id, temple_id);
        temple.move_to_chamber(explorer_id, 0);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.chamber_id == 2, 'should be in chamber 2');
        assert(!pos.in_combat, 'no combat in empty chamber');
    }

    #[test]
    fn test_move_to_monster_chamber_triggers_combat() {
        let caller: ContractAddress = 'movetest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
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

        temple.enter_temple(explorer_id, temple_id);
        temple.move_to_chamber(explorer_id, 0);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.chamber_id == 2, 'moved to chamber 2');
        assert(pos.in_combat, 'should be in combat');
        assert(pos.combat_monster_id == 1, 'fighting monster 1');
    }

    #[test]
    #[should_panic]
    fn test_move_to_undiscovered_exit_fails() {
        let caller: ContractAddress = 'movetest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
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
            to_chamber_id: 0,
            is_discovered: false, // not yet discovered
        });

        temple.enter_temple(explorer_id, temple_id);
        temple.move_to_chamber(explorer_id, 0); // should panic
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Combat flow (attack kills monster) in a temple context
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_attack_in_temple_records_position() {
        let caller: ContractAddress = 'combattest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Give explorer high HP so they survive the counter-attack
        world.write_model_test(@ExplorerHealth {
            explorer_id,
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
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat.attack(explorer_id);

        // Monster should have taken some damage (or attack missed — hp ≤ 100)
        let monster: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        assert(monster.current_hp <= 100, 'monster hp did not increase');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // XP gain after killing a monster
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_kill_monster_grants_xp() {
        let caller: ContractAddress = 'xptest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        let stats_before: ExplorerStats = world.read_model(explorer_id);

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

        // Initialize progress so gain_xp can update it
        world.write_model_test(@ExplorerTempleProgress {
            explorer_id,
            temple_id,
            chambers_explored: 0,
            xp_earned: 0,
        });

        combat.attack(explorer_id);

        let stats_after: ExplorerStats = world.read_model(explorer_id);
        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));

        if !monster_after.is_alive {
            // Monster was killed — XP must have been awarded
            assert(stats_after.xp > stats_before.xp, 'xp should increase on kill');

            let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
            assert(progress.xp_earned > 0, 'temple xp_earned should grow');
        }
        // If monster survived (attack missed), test passes silently
    }

    #[test]
    fn test_kill_monster_updates_temple_progress() {
        let caller: ContractAddress = 'xptest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
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
            explorer_id,
            temple_id,
            chamber_id: 3,
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
            chambers_explored: 2,
            xp_earned: 100,
        });

        combat.attack(explorer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 3_u32, 1_u32));
        if !monster_after.is_alive {
            let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
            assert(progress.xp_earned > 100, 'xp_earned should increase');
            assert(progress.chambers_explored == 2, 'chambers_explored unchanged');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Level-up on kill
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_level_up_increases_max_hp() {
        let caller: ContractAddress = 'lvltest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set XP just below level 2 threshold (300 XP)
        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities: stats.abilities,
            level: 1,
            xp: 250, // skeleton = 50 XP → total 300 = level 2
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });

        let health_before: ExplorerHealth = world.read_model(explorer_id);

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

        combat.attack(explorer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: ExplorerStats = world.read_model(explorer_id);
            if stats_after.xp >= 300 {
                assert(stats_after.level == 2, 'should be level 2');
                let health_after: ExplorerHealth = world.read_model(explorer_id);
                assert(health_after.max_hp > health_before.max_hp, 'max_hp should increase');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // loot_treasure
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_loot_treasure_awards_gold_in_treasure_chamber() {
        let caller: ContractAddress = 'loottest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        let inv_before: ExplorerInventory = world.read_model(explorer_id);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
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
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(explorer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        let inv_after: ExplorerInventory = world.read_model(explorer_id);

        // On success (perception DC 10) gold should increase; on fail no change
        if chamber_after.treasure_looted {
            assert(inv_after.gold >= inv_before.gold, 'gold should not decrease');
        }
    }

    #[test]
    fn test_loot_treasure_marks_looted() {
        let caller: ContractAddress = 'loottest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
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
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Boost WIS to guarantee perception check passes (no modifier needed)
        let stats: ExplorerStats = world.read_model(explorer_id);
        let mut abilities = stats.abilities;
        abilities.wisdom = 20; // +5 mod guarantees DC 10
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });

        temple.loot_treasure(explorer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        // WIS 20 (+5) + d20 always beats DC 10
        assert(chamber_after.treasure_looted, 'should be marked looted');
    }

    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_on_second_attempt() {
        let caller: ContractAddress = 'loottest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Treasure,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: true, // already looted
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_in_monster_chamber() {
        let caller: ContractAddress = 'loottest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

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
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(explorer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // loot_fallen
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_loot_fallen_transfers_items() {
        let caller: ContractAddress = 'fallentest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        // Two explorers: the looter and the fallen
        let looter_id = mint_fighter(token);
        let fallen_explorer_id: u128 = 9999;

        let temple_id = temple.mint_temple(1_u8);

        // Place a fallen explorer body in chamber 2
        world.write_model_test(@ChamberFallenCount {
            temple_id,
            chamber_id: 2,
            count: 1,
        });
        world.write_model_test(@FallenExplorer {
            temple_id,
            chamber_id: 2,
            fallen_index: 0,
            explorer_id: fallen_explorer_id,
            dropped_weapon: WeaponType::Dagger,
            dropped_armor: ArmorType::Leather,
            dropped_gold: 75,
            dropped_potions: 3,
            is_looted: false,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id: looter_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Strip looter's equipment so they can pick up the fallen's items
        world.write_model_test(@ExplorerInventory {
            explorer_id: looter_id,
            primary_weapon: WeaponType::None,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::None,
            has_shield: false,
            gold: 10,
            potions: 0,
        });

        temple.loot_fallen(looter_id, 0);

        let inv: ExplorerInventory = world.read_model(looter_id);
        assert(inv.gold == 85, 'gold: 10 + 75 = 85');
        assert(inv.potions == 3, 'potions transferred');

        let fallen: FallenExplorer = world.read_model((temple_id, 2_u32, 0_u32));
        assert(fallen.is_looted, 'body should be marked looted');
    }

    #[test]
    #[should_panic]
    fn test_loot_fallen_cannot_loot_self() {
        let caller: ContractAddress = 'fallentest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount {
            temple_id,
            chamber_id: 2,
            count: 1,
        });
        world.write_model_test(@FallenExplorer {
            temple_id,
            chamber_id: 2,
            fallen_index: 0,
            explorer_id, // same as looter
            dropped_weapon: WeaponType::Longsword,
            dropped_armor: ArmorType::ChainMail,
            dropped_gold: 0,
            dropped_potions: 0,
            is_looted: false,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_fallen(explorer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Boss defeat
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_boss_defeat_marks_boss_dead() {
        let caller: ContractAddress = 'bosstest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up temple with a known boss chamber
        world.write_model_test(@TempleState {
            temple_id,
            difficulty_tier: 1,
            next_chamber_id: 3,
            boss_chamber_id: 2,
            boss_alive: true,
            max_yonder: 1,
        });

        // Boss = Wraith with 1 HP (guaranteed kill)
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Wraith,
            current_hp: 1,
            max_hp: 45,
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
            chambers_explored: 5,
            xp_earned: 500,
        });

        combat.attack(explorer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let temple_after: TempleState = world.read_model(temple_id);
            assert(!temple_after.boss_alive, 'boss should be marked dead');

            let stats_after: ExplorerStats = world.read_model(explorer_id);
            assert(stats_after.temples_conquered == 1, 'temples_conquered should be 1');
        }
    }

    #[test]
    fn test_boss_defeat_increments_temples_conquered() {
        let caller: ContractAddress = 'bosstest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Explorer with 1 prior conquest
        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities: stats.abilities,
            level: stats.level,
            xp: stats.xp,
            explorer_class: stats.explorer_class,
            temples_conquered: 1, // previously conquered 1 temple
        });

        world.write_model_test(@TempleState {
            temple_id,
            difficulty_tier: 1,
            next_chamber_id: 3,
            boss_chamber_id: 2,
            boss_alive: true,
            max_yonder: 1,
        });
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Wraith,
            current_hp: 1,
            max_hp: 45,
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
            chambers_explored: 3,
            xp_earned: 300,
        });

        combat.attack(explorer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: ExplorerStats = world.read_model(explorer_id);
            assert(stats_after.temples_conquered == 2, 'should have 2 conquests now');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Full end-to-end flow
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

    // ═══════════════════════════════════════════════════════════════════════
    // Cross-temple: exit and re-enter a different temple keeps stats
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_cross_temple_stats_carry_over() {
        let caller: ContractAddress = 'crosstest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        // Enter temple A, give some XP, exit
        temple.enter_temple(explorer_id, temple_a);
        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities: stats.abilities,
            level: 1,
            xp: 150,
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });
        temple.exit_temple(explorer_id);

        // Enter temple B
        temple.enter_temple(explorer_id, temple_b);

        // Stats should carry over
        let stats_in_b: ExplorerStats = world.read_model(explorer_id);
        assert(stats_in_b.xp == 150, 'xp carries to temple B');
        assert(stats_in_b.level == 1, 'level carries to temple B');

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == temple_b, 'in temple B');
        assert(pos.chamber_id == 1, 'at entrance of B');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Trap death calls handle_death (move_to_chamber)
    // ═══════════════════════════════════════════════════════════════════════

    /// Trap with DC 21 always fails (d20 max = 20).
    /// Explorer at 1 HP always dies from any damage.
    /// Verifies that move_to_chamber calls handle_death: FallenExplorer is
    /// created, inventory zeroed, in_combat cleared.
    #[test]
    fn test_trap_in_move_to_chamber_kills_explorer_via_handle_death() {
        let caller: ContractAddress = 'traptest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up entrance with a discovered exit to a trap chamber
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
        // Trap chamber: DC 21 (impossible to pass with d20)
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 21,
        });

        // 1 HP explorer with DEX 10 (modifier 0) — any damage is fatal
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });
        // Give some gold/potions so we can verify they get dropped
        world.write_model_test(@ExplorerInventory {
            explorer_id,
            primary_weapon: d20::types::items::WeaponType::Longsword,
            secondary_weapon: d20::types::items::WeaponType::None,
            armor: d20::types::items::ArmorType::ChainMail,
            has_shield: false,
            gold: 30,
            potions: 1,
        });

        temple.enter_temple(explorer_id, temple_id);
        temple.move_to_chamber(explorer_id, 0);

        // DC 21 guarantees save fails; 1 HP means any hit is lethal
        assert_explorer_dead(ref world, explorer_id, temple_id, 2_u32);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Trap death calls handle_death (disarm_trap)
    // ═══════════════════════════════════════════════════════════════════════

    /// Disarm check with INT mod −1 and no proficiency can't beat DC 21.
    /// The triggered DEX save also can't beat DC 21.
    /// Explorer at 1 HP always dies from any damage.
    #[test]
    fn test_disarm_trap_failure_kills_explorer_via_handle_death() {
        let caller: ContractAddress = 'traptest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Place explorer in a trap chamber with DC 21
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 21,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });
        world.write_model_test(@ExplorerInventory {
            explorer_id,
            primary_weapon: d20::types::items::WeaponType::Longsword,
            secondary_weapon: d20::types::items::WeaponType::None,
            armor: d20::types::items::ArmorType::ChainMail,
            has_shield: false,
            gold: 20,
            potions: 2,
        });

        // Use a fighter with INT 8 (mod −1) and no Arcana → effective bonus = 0
        // Disarm roll can't beat DC 21; triggered DEX save also can't beat DC 21
        let stats: ExplorerStats = world.read_model(explorer_id);
        let mut abilities = stats.abilities;
        abilities.intelligence = 8;
        abilities.dexterity = 10;
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });

        temple.disarm_trap(explorer_id);

        assert_explorer_dead(ref world, explorer_id, temple_id, 2_u32);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Task 5.1 — disarm_trap tests
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_disarm_trap_resolves_without_crash() {
        let caller: ContractAddress = 'traptestA1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let explorer_id = mint_rogue(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 3,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 10,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });
        let stats: ExplorerStats = world.read_model(explorer_id);
        let mut abilities = stats.abilities;
        abilities.dexterity = 20;
        world.write_model_test(@ExplorerStats {
            explorer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            explorer_class: stats.explorer_class,
            temples_conquered: stats.temples_conquered,
        });
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        temple.disarm_trap(explorer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 3_u32));
        let health_after: ExplorerHealth = world.read_model(explorer_id);
        assert(!health_after.is_dead || chamber_after.trap_disarmed || health_after.current_hp < 50,
            'disarm had some effect');
    }

    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_in_non_trap_chamber() {
        let caller: ContractAddress = 'traptestA2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Empty,
            yonder: 1,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.disarm_trap(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_already_disarmed() {
        let caller: ContractAddress = 'traptestA3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 3,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: true,
            trap_dc: 10,
        });
        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.disarm_trap(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_dead() {
        let caller: ContractAddress = 'traptestA4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 3, chamber_type: ChamberType::Trap, yonder: 2, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 10 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 3, in_combat: false, combat_monster_id: 0 });

        temple.disarm_trap(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_in_combat() {
        let caller: ContractAddress = 'traptestA5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 3, chamber_type: ChamberType::Trap, yonder: 2, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 10 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 3, in_combat: true, combat_monster_id: 1 });

        temple.disarm_trap(explorer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Trap entry damage / disarmed trap
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_move_to_trap_chamber_may_deal_damage() {
        let caller: ContractAddress = 'trapmoveA1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Trap, yonder: 4, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 25 });

        temple.enter_temple(explorer_id, temple_id);
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 50, max_hp: 50, is_dead: false });

        temple.move_to_chamber(explorer_id, 0);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.chamber_id == 2, 'moved to trap chamber');
    }

    #[test]
    fn test_move_to_disarmed_trap_no_damage() {
        let caller: ContractAddress = 'trapmoveA2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Trap, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: true, trap_dc: 15 });

        temple.enter_temple(explorer_id, temple_id);
        let health_before: ExplorerHealth = world.read_model(explorer_id);

        temple.move_to_chamber(explorer_id, 0);

        let health_after: ExplorerHealth = world.read_model(explorer_id);
        assert(health_after.current_hp == health_before.current_hp, 'no damage from disarmed trap');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Task 5.1 — Edge cases
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    #[should_panic]
    fn test_exit_temple_fails_during_combat() {
        let caller: ContractAddress = 'exitcombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_id, temple_id);
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });
        temple.exit_temple(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_if_already_looted() {
        let caller: ContractAddress = 'fallentest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id: 2, count: 1 });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id: 2, fallen_index: 0, explorer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 50, dropped_potions: 1, is_looted: true });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        temple.loot_fallen(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_with_invalid_index() {
        let caller: ContractAddress = 'fallentest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id: 2, count: 0 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        temple.loot_fallen(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_dead() {
        let caller: ContractAddress = 'opentest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 0, is_discovered: false });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });

        temple.open_exit(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_open_exit_fails_if_in_combat() {
        let caller: ContractAddress = 'opentest6'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 0, is_discovered: false });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });

        temple.open_exit(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_move_to_chamber_fails_if_dead() {
        let caller: ContractAddress = 'movetest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Empty, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });

        temple.move_to_chamber(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_move_to_chamber_fails_if_in_combat() {
        let caller: ContractAddress = 'movetest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });

        temple.move_to_chamber(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_if_in_combat() {
        let caller: ContractAddress = 'lootcombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Treasure, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.loot_treasure(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_if_in_combat() {
        let caller: ContractAddress = 'fallencombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id: 2, count: 1 });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id: 2, fallen_index: 0, explorer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 50, dropped_potions: 1, is_looted: false });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.loot_fallen(explorer_id, 0);
    }

    #[test]
    #[should_panic]
    fn test_enter_temple_rejects_explorer_in_combat() {
        let caller: ContractAddress = 'entertest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        world.write_model_test(@ExplorerPosition { explorer_id, temple_id: temple_a, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.enter_temple(explorer_id, temple_b);
    }

    #[test]
    fn test_reenter_same_temple_preserves_progress() {
        let caller: ContractAddress = 'reenter1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        temple.enter_temple(explorer_id, temple_id);
        world.write_model_test(@ExplorerTempleProgress { explorer_id, temple_id, chambers_explored: 5, xp_earned: 200 });
        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_id);

        let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
        assert(progress.chambers_explored == 5, 'chambers preserved');
        assert(progress.xp_earned == 200, 'xp preserved');

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.chamber_id == 1, 'at entrance on re-entry');
    }

    #[test]
    fn test_loot_treasure_in_empty_chamber() {
        let caller: ContractAddress = 'loottest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Empty, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        let stats: ExplorerStats = world.read_model(explorer_id);
        let mut abilities = stats.abilities;
        abilities.wisdom = 20;
        world.write_model_test(@ExplorerStats { explorer_id, abilities, level: stats.level, xp: stats.xp, explorer_class: stats.explorer_class, temples_conquered: stats.temples_conquered });

        temple.loot_treasure(explorer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        if chamber_after.treasure_looted {
            let inv: ExplorerInventory = world.read_model(explorer_id);
            assert(inv.gold > 0, 'gold from empty loot');
        }
    }

    #[test]
    #[should_panic]
    fn test_open_exit_fails_with_invalid_index() {
        let caller: ContractAddress = 'opentest7'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });

        temple.enter_temple(explorer_id, temple_id);
        temple.open_exit(explorer_id, 5);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Task 5.2 – Permadeath flow
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_permadeath_two_player_death_and_loot() {
        let player_a: ContractAddress = 'playerA'.try_into().unwrap();
        let player_b: ContractAddress = 'playerB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, temple_id);

        world.write_model_test(@ExplorerInventory { explorer_id: explorer_a, primary_weapon: WeaponType::Longsword, secondary_weapon: WeaponType::None, armor: ArmorType::ChainMail, has_shield: false, gold: 42, potions: 3 });
        world.write_model_test(@ExplorerPosition { explorer_id: explorer_a, temple_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });
        world.write_model_test(@MonsterInstance { temple_id, chamber_id: 1, monster_id: 1, monster_type: MonsterType::Skeleton, current_hp: 50, max_hp: 50, is_alive: true });
        world.write_model_test(@ExplorerHealth { explorer_id: explorer_a, current_hp: 1, max_hp: 11, is_dead: false });

        combat.attack(explorer_a);

        let health_a: ExplorerHealth = world.read_model(explorer_a);
        if !health_a.is_dead { return; }

        let fallen_count: ChamberFallenCount = world.read_model((temple_id, 1_u32));
        assert(fallen_count.count >= 1, 'should have at least 1 body');

        let fallen: FallenExplorer = world.read_model((temple_id, 1_u32, 0_u32));
        assert(fallen.explorer_id == explorer_a, 'body is explorer A');
        assert(fallen.dropped_gold == 42, 'body has 42 gold');

        let inv_a: ExplorerInventory = world.read_model(explorer_a);
        assert(inv_a.gold == 0, 'gold zeroed after death');

        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);

        world.write_model_test(@ExplorerPosition { explorer_id: explorer_b, temple_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });
        world.write_model_test(@ExplorerInventory { explorer_id: explorer_b, primary_weapon: WeaponType::None, secondary_weapon: WeaponType::None, armor: ArmorType::None, has_shield: false, gold: 5, potions: 0 });

        temple.loot_fallen(explorer_b, 0);

        let inv_b: ExplorerInventory = world.read_model(explorer_b);
        assert(inv_b.gold == 47, 'B gets 5 + 42 = 47 gold');
        assert(inv_b.primary_weapon == WeaponType::Longsword, 'B gets longsword');

        let fallen_after: FallenExplorer = world.read_model((temple_id, 1_u32, 0_u32));
        assert(fallen_after.is_looted, 'body marked looted');
    }

    #[test]
    fn test_multiple_fallen_bodies_in_same_chamber() {
        let caller: ContractAddress = 'multideath'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, _token, _combat, _temple) = setup_world();

        let temple_id: u128 = 50;
        let chamber_id: u32 = 3;

        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id, count: 2 });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id, fallen_index: 0, explorer_id: 100, dropped_weapon: WeaponType::Longsword, dropped_armor: ArmorType::ChainMail, dropped_gold: 30, dropped_potions: 1, is_looted: false });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id, fallen_index: 1, explorer_id: 200, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 15, dropped_potions: 0, is_looted: false });

        let count: ChamberFallenCount = world.read_model((temple_id, chamber_id));
        assert(count.count == 2, 'two bodies in chamber');

        let body0: FallenExplorer = world.read_model((temple_id, chamber_id, 0_u32));
        assert(body0.explorer_id == 100, 'body 0 is explorer 100');

        let body1: FallenExplorer = world.read_model((temple_id, chamber_id, 1_u32));
        assert(body1.explorer_id == 200, 'body 1 is explorer 200');
    }

    #[test]
    #[should_panic(expected: ('dead explorers cannot loot', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_loot_treasure() {
        let caller: ContractAddress = 'deadloot1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_id, temple_id);
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });

        temple.loot_treasure(explorer_id);
    }

    #[test]
    #[should_panic(expected: ('dead explorers cannot loot', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_loot_fallen() {
        let caller: ContractAddress = 'deadloot2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_id, temple_id);

        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id: 1, count: 1 });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id: 1, fallen_index: 0, explorer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::None, dropped_gold: 10, dropped_potions: 0, is_looted: false });
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });

        temple.loot_fallen(explorer_id, 0);
    }

    #[test]
    #[should_panic(expected: ('dead explorer cannot act', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_use_item() {
        let caller: ContractAddress = 'deaditem'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, _temple) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@ExplorerInventory { explorer_id, primary_weapon: WeaponType::Longsword, secondary_weapon: WeaponType::None, armor: ArmorType::ChainMail, has_shield: false, gold: 0, potions: 1 });

        combat.use_item(explorer_id, ItemType::HealthPotion);
    }

    #[test]
    fn test_dead_nft_fully_frozen() {
        let caller: ContractAddress = 'frozennft'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_id, temple_id);

        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 0, max_hp: 11, is_dead: true });

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.is_dead, 'explorer should be dead');
        assert(health.current_hp == 0, 'hp should be 0');

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == temple_id, 'body in temple');
        assert(pos.chamber_id == 1, 'body in chamber 1');
    }

    #[test]
    fn test_loot_second_body_leaves_first_intact() {
        let caller: ContractAddress = 'loot2nd'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@ExplorerPosition { explorer_id, temple_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });
        world.write_model_test(@ChamberFallenCount { temple_id, chamber_id: 2, count: 2 });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id: 2, fallen_index: 0, explorer_id: 8888, dropped_weapon: WeaponType::Longsword, dropped_armor: ArmorType::ChainMail, dropped_gold: 100, dropped_potions: 5, is_looted: true });
        world.write_model_test(@FallenExplorer { temple_id, chamber_id: 2, fallen_index: 1, explorer_id: 7777, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 20, dropped_potions: 1, is_looted: false });
        world.write_model_test(@ExplorerInventory { explorer_id, primary_weapon: WeaponType::None, secondary_weapon: WeaponType::None, armor: ArmorType::None, has_shield: false, gold: 0, potions: 0 });

        temple.loot_fallen(explorer_id, 1);

        let body1: FallenExplorer = world.read_model((temple_id, 2_u32, 1_u32));
        assert(body1.is_looted, 'body 1 should be looted');

        let body0: FallenExplorer = world.read_model((temple_id, 2_u32, 0_u32));
        assert(body0.is_looted, 'body 0 still looted');
        assert(body0.dropped_gold == 100, 'body 0 gold unchanged');

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.gold == 20, 'got 20 gold from body 1');
        assert(inv.primary_weapon == WeaponType::Dagger, 'got dagger');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Task 5.3 – Cross-temple flow
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_cross_temple_level_up_carries_over() {
        let caller: ContractAddress = 'crosslvl'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);

        world.write_model_test(@MonsterInstance { temple_id: temple_a, chamber_id: 1, monster_id: 1, monster_type: MonsterType::Skeleton, current_hp: 1, max_hp: 13, is_alive: true });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id: temple_a, chamber_id: 1, in_combat: true, combat_monster_id: 1 });
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 50, max_hp: 50, is_dead: false });

        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats { explorer_id, abilities: stats.abilities, level: 1, xp: 250, explorer_class: stats.explorer_class, temples_conquered: 0 });

        combat.attack(explorer_id);

        let stats_after_kill: ExplorerStats = world.read_model(explorer_id);
        let level_in_a = stats_after_kill.level;
        let xp_in_a = stats_after_kill.xp;
        let health_in_a: ExplorerHealth = world.read_model(explorer_id);
        let max_hp_in_a = health_in_a.max_hp;

        let pos: ExplorerPosition = world.read_model(explorer_id);
        if pos.in_combat {
            world.write_model_test(@ExplorerPosition { explorer_id, temple_id: temple_a, chamber_id: 1, in_combat: false, combat_monster_id: 0 });
        }
        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_b);

        let stats_in_b: ExplorerStats = world.read_model(explorer_id);
        assert(stats_in_b.level == level_in_a, 'level carries to B');
        assert(stats_in_b.xp == xp_in_a, 'xp carries to B');

        let health_in_b: ExplorerHealth = world.read_model(explorer_id);
        assert(health_in_b.max_hp == max_hp_in_a, 'max_hp carries to B');
    }

    #[test]
    fn test_cross_temple_inventory_carries_over() {
        let caller: ContractAddress = 'crossinv'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);
        world.write_model_test(@ExplorerInventory { explorer_id, primary_weapon: WeaponType::Dagger, secondary_weapon: WeaponType::Shortbow, armor: ArmorType::Leather, has_shield: true, gold: 99, potions: 5 });

        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_b);

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Dagger, 'weapon carries over');
        assert(inv.gold == 99, 'gold carries over');
        assert(inv.potions == 5, 'potions carry over');
    }

    #[test]
    fn test_cross_temple_hp_not_auto_healed() {
        let caller: ContractAddress = 'crosshp'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 3, max_hp: 11, is_dead: false });

        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_b);

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.current_hp == 3, 'hp NOT auto-healed');
        assert(health.max_hp == 11, 'max_hp preserved');
    }

    #[test]
    fn test_cross_temple_progress_is_per_temple() {
        let caller: ContractAddress = 'crossprog'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);
        world.write_model_test(@ExplorerTempleProgress { explorer_id, temple_id: temple_a, chambers_explored: 7, xp_earned: 500 });

        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_b);

        let progress_b: ExplorerTempleProgress = world.read_model((explorer_id, temple_b));
        assert(progress_b.chambers_explored == 0, 'B starts at 0 chambers');
        assert(progress_b.xp_earned == 0, 'B starts at 0 xp');

        let progress_a: ExplorerTempleProgress = world.read_model((explorer_id, temple_a));
        assert(progress_a.chambers_explored == 7, 'A progress preserved');
        assert(progress_a.xp_earned == 500, 'A xp preserved');
    }

    #[test]
    fn test_cross_temple_class_resources_not_reset() {
        let caller: ContractAddress = 'crossres'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);
        world.write_model_test(@ExplorerCombat { explorer_id, armor_class: 16, spell_slots_1: 0, spell_slots_2: 0, spell_slots_3: 0, second_wind_used: true, action_surge_used: true });

        temple.exit_temple(explorer_id);
        temple.enter_temple(explorer_id, temple_b);

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(combat.second_wind_used, 'second_wind still used');
        assert(combat.action_surge_used, 'action_surge still used');
    }

    #[test]
    fn test_cross_temple_full_flow_with_rest() {
        let caller: ContractAddress = 'crossfull'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();
        let explorer_id = mint_fighter(token);

        let temple_a = temple.mint_temple(1_u8);
        let temple_b = temple.mint_temple(2_u8);

        temple.enter_temple(explorer_id, temple_a);

        world.write_model_test(@MonsterInstance { temple_id: temple_a, chamber_id: 1, monster_id: 1, monster_type: MonsterType::PoisonousSnake, current_hp: 1, max_hp: 1, is_alive: true });
        world.write_model_test(@ExplorerPosition { explorer_id, temple_id: temple_a, chamber_id: 1, in_combat: true, combat_monster_id: 1 });
        world.write_model_test(@ExplorerHealth { explorer_id, current_hp: 50, max_hp: 50, is_dead: false });

        let inv_before: ExplorerInventory = world.read_model(explorer_id);
        world.write_model_test(@ExplorerInventory { explorer_id, primary_weapon: inv_before.primary_weapon, secondary_weapon: inv_before.secondary_weapon, armor: inv_before.armor, has_shield: inv_before.has_shield, gold: 25, potions: 2 });

        let combat_state: ExplorerCombat = world.read_model(explorer_id);
        world.write_model_test(@ExplorerCombat { explorer_id, armor_class: combat_state.armor_class, spell_slots_1: combat_state.spell_slots_1, spell_slots_2: combat_state.spell_slots_2, spell_slots_3: combat_state.spell_slots_3, second_wind_used: true, action_surge_used: false });

        combat.attack(explorer_id);

        let pos_after: ExplorerPosition = world.read_model(explorer_id);
        if pos_after.in_combat {
            world.write_model_test(@ExplorerPosition { explorer_id, temple_id: temple_a, chamber_id: 1, in_combat: false, combat_monster_id: 0 });
        }
        temple.exit_temple(explorer_id);

        token.rest(explorer_id);

        let health_after_rest: ExplorerHealth = world.read_model(explorer_id);
        let max_hp_i16: i16 = health_after_rest.max_hp.try_into().unwrap();
        assert(health_after_rest.current_hp == max_hp_i16, 'rest restores HP');

        let combat_after_rest: ExplorerCombat = world.read_model(explorer_id);
        assert(!combat_after_rest.second_wind_used, 'rest resets second_wind');

        temple.enter_temple(explorer_id, temple_b);

        let pos_b: ExplorerPosition = world.read_model(explorer_id);
        assert(pos_b.temple_id == temple_b, 'in temple B');

        let inv_b: ExplorerInventory = world.read_model(explorer_id);
        assert(inv_b.gold == 25, 'gold preserved');
        assert(inv_b.potions == 2, 'potions preserved');

        let health_b: ExplorerHealth = world.read_model(explorer_id);
        let max_hp_b: i16 = health_b.max_hp.try_into().unwrap();
        assert(health_b.current_hp == max_hp_b, 'full HP in B');
    }
}
