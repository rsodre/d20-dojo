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
use d20::d20::models::adventurer::{
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
use d20::d20::types::adventurer_class::AdventurerClass;
use d20::types::monster::MonsterType;
use d20::tests::mock_vrf::MockVrf;

// ── Test world setup ──────────────────────────────────────────────────────

pub fn namespace_def() -> NamespaceDef {
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

pub fn setup_world() -> (
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

pub fn mint_fighter(token: IExplorerTokenDispatcher) -> u128 {
    token.mint_explorer(AdventurerClass::Fighter)
}

pub fn mint_rogue(token: IExplorerTokenDispatcher) -> u128 {
    token.mint_explorer(AdventurerClass::Rogue)
}

pub fn mint_wizard(token: IExplorerTokenDispatcher) -> u128 {
    token.mint_explorer(AdventurerClass::Wizard)
}

// ── Death assertion helper ────────────────────────────────────────────────

/// Validates all invariants that must hold after an explorer dies:
/// - is_dead flag set, HP at 0, not in combat
/// - FallenExplorer record created in the correct chamber
/// - ChamberFallenCount incremented
/// - Inventory gold and potions zeroed (dropped as loot)
pub fn assert_explorer_dead(
    ref world: dojo::world::WorldStorage,
    adventurer_id: u128,
    temple_id: u128,
    chamber_id: u32,
) {
    let health: ExplorerHealth = world.read_model(adventurer_id);
    assert(health.is_dead, 'explorer should be dead');
    assert(health.current_hp == 0, 'hp should be 0 on death');

    let pos: ExplorerPosition = world.read_model(adventurer_id);
    assert(!pos.in_combat, 'dead explorer not in combat');

    let fallen_count: ChamberFallenCount = world.read_model((temple_id, chamber_id));
    assert(fallen_count.count >= 1, 'fallen count should be >= 1');

    let fallen: FallenExplorer = world.read_model(
        (temple_id, chamber_id, fallen_count.count - 1)
    );
    assert(fallen.adventurer_id == adventurer_id, 'fallen explorer id mismatch');
    assert(!fallen.is_looted, 'fallen should not be looted');

    let inv: ExplorerInventory = world.read_model(adventurer_id);
    assert(inv.gold == 0, 'gold dropped on death');
    assert(inv.potions == 0, 'potions dropped on death');
}
