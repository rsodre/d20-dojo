use starknet::{SyscallResultTrait};
use starknet::syscalls::{deploy_syscall};
use dojo::model::{ModelStorage};
use dojo::world::{WorldStorageTrait, world};
use dojo_cairo_test::{
    spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    WorldStorageTestTrait,
};

use d20::systems::explorer_token::{
    IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
};
use d20::systems::combat_system::{ICombatSystemDispatcher};
use d20::systems::temple_token::{ITempleTokenDispatcher};
use d20::models::config::m_Config;
use d20::d20::models::character::{
    CharacterStats, CharacterInventory, CharacterPosition,
};
use d20::d20::models::dungeon::{FallenCharacter, Chamber};
use d20::d20::types::character_class::CharacterClass;
use d20::tests::mock_vrf::MockVrf;

// ── Test world setup ──────────────────────────────────────────────────────

pub fn namespace_def() -> NamespaceDef {
    NamespaceDef {
        namespace: "d20_0_1",
        resources: [
            // Config
            TestResource::Model(m_Config::TEST_CLASS_HASH),
            // Explorer models
            TestResource::Model(d20::d20::models::character::m_CharacterStats::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::character::m_CharacterCombat::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::character::m_CharacterInventory::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::character::m_CharacterPosition::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::character::m_CharacterSkills::TEST_CLASS_HASH),
            // Temple models
            TestResource::Model(d20::d20::models::dungeon::m_DungeonState::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::dungeon::m_Chamber::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::dungeon::m_MonsterInstance::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::dungeon::m_ChamberExit::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::dungeon::m_FallenCharacter::TEST_CLASS_HASH),
            TestResource::Model(d20::d20::models::dungeon::m_CharacterDungeonProgress::TEST_CLASS_HASH),
            // Events
            TestResource::Event(d20::d20::models::events::e_CharacterMinted::TEST_CLASS_HASH),
            TestResource::Event(d20::d20::models::events::e_CombatResult::TEST_CLASS_HASH),
            TestResource::Event(d20::d20::models::events::e_CharacterDied::TEST_CLASS_HASH),
            TestResource::Event(d20::d20::models::events::e_ChamberRevealed::TEST_CLASS_HASH),
            TestResource::Event(d20::d20::models::events::e_LevelUp::TEST_CLASS_HASH),
            TestResource::Event(d20::d20::models::events::e_BossDefeated::TEST_CLASS_HASH),
            // Contracts
            TestResource::Contract(d20::systems::explorer_token::explorer_token::TEST_CLASS_HASH),
            TestResource::Contract(d20::systems::combat_system::combat_system::TEST_CLASS_HASH),
            TestResource::Contract(d20::systems::temple_token::temple_token::TEST_CLASS_HASH),
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
    token.mint_explorer(CharacterClass::Fighter)
}

pub fn mint_rogue(token: IExplorerTokenDispatcher) -> u128 {
    token.mint_explorer(CharacterClass::Rogue)
}

pub fn mint_wizard(token: IExplorerTokenDispatcher) -> u128 {
    token.mint_explorer(CharacterClass::Wizard)
}

// ── Death assertion helper ────────────────────────────────────────────────

/// Validates all invariants that must hold after an explorer dies:
/// - is_dead flag set, HP at 0, not in combat
/// - FallenCharacter record created in the correct chamber
/// - Chamber.fallen_count incremented
/// - Inventory gold and potions zeroed (dropped as loot)
pub fn assert_explorer_dead(
    ref world: dojo::world::WorldStorage,
    character_id: u128,
    dungeon_id: u128,
    chamber_id: u32,
) {
    let stats: CharacterStats = world.read_model(character_id);
    assert(stats.is_dead, 'explorer should be dead');
    assert(stats.current_hp == 0, 'hp should be 0 on death');

    let pos: CharacterPosition = world.read_model(character_id);
    assert(!pos.in_combat, 'dead character not in combat');

    let chamber: Chamber = world.read_model((dungeon_id, chamber_id));
    assert(chamber.fallen_count >= 1, 'fallen count should be >= 1');

    let fallen: FallenCharacter = world.read_model(
        (dungeon_id, chamber_id, chamber.fallen_count - 1)
    );
    assert(fallen.character_id == character_id, 'fallen explorer id mismatch');
    assert(!fallen.is_looted, 'fallen should not be looted');

    let inv: CharacterInventory = world.read_model(character_id);
    assert(inv.gold == 0, 'gold dropped on death');
    assert(inv.potions == 0, 'potions dropped on death');
}
