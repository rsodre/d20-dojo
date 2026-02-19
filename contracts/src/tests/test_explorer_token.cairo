#[cfg(test)]
mod tests {

    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::syscalls::deploy_syscall;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait,
    };

    use d20::systems::explorer_token::{
        explorer_token, IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
    };
    use d20::models::config::m_Config;
    use d20::models::explorer::{
        ExplorerStats, m_ExplorerStats,
        ExplorerHealth, m_ExplorerHealth,
        ExplorerCombat, m_ExplorerCombat,
        ExplorerInventory, m_ExplorerInventory,
        ExplorerPosition, m_ExplorerPosition,
        ExplorerSkills, m_ExplorerSkills,
    };
    use d20::events::{e_ExplorerMinted};
    use d20::types::index::Skill;
    use d20::types::items::{WeaponType, ArmorType};
    use d20::types::explorer_class::ExplorerClass;
    use d20::tests::mock_vrf::MockVrf;

    // ── Test world setup ──────────────────────────────────────────────────────

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: [
                TestResource::Model(m_Config::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerStats::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerHealth::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerCombat::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerInventory::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerPosition::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerSkills::TEST_CLASS_HASH),
                TestResource::Event(e_ExplorerMinted::TEST_CLASS_HASH),
                TestResource::Contract(explorer_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    /// Deploy MockVrf and wire it to explorer_token via dojo_init calldata.
    fn setup_world() -> (dojo::world::WorldStorage, IExplorerTokenDispatcher) {
        let (mock_vrf_address, _) = deploy_syscall(
            MockVrf::TEST_CLASS_HASH, 0, [].span(), false,
        ).unwrap_syscall();

        let contract_defs: Span<ContractDef> = [
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
        ].span();

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        (world, IExplorerTokenDispatcher { contract_address })
    }

    // ── Helper: verify standard array invariant ───────────────────────────────

    /// Assert each stat value is from [15,14,13,12,10,8].
    fn assert_standard_array(stats: @ExplorerStats) {
        assert_valid_stat(*stats.abilities.strength);
        assert_valid_stat(*stats.abilities.dexterity);
        assert_valid_stat(*stats.abilities.constitution);
        assert_valid_stat(*stats.abilities.intelligence);
        assert_valid_stat(*stats.abilities.wisdom);
        assert_valid_stat(*stats.abilities.charisma);
        // Also verify the total equals 15+14+13+12+10+8 = 72
        let total: u16 = (*stats.abilities.strength).into() + (*stats.abilities.dexterity).into()
            + (*stats.abilities.constitution).into() + (*stats.abilities.intelligence).into()
            + (*stats.abilities.wisdom).into() + (*stats.abilities.charisma).into();
        assert(total == 72, 'stats sum must be 72');
    }

    fn assert_valid_stat(v: u8) {
        assert(v == 8 || v == 10 || v == 12 || v == 13 || v == 14 || v == 15,
               'stat not in standard array');
    }

    // ── Fighter tests ─────────────────────────────────────────────────────────

    #[test]
    fn test_mint_fighter_basic() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        // ERC-721 token ID starts at 1
        assert(explorer_id == 1_u128, 'explorer_id should be 1');

        // Verify ERC721 state
        assert(token.total_supply() == 1_u256, 'supply should be 1');
        assert(token.balance_of(caller) == 1_u256, 'balance should be 1');
        assert(token.owner_of(explorer_id.into()) == caller, 'wrong owner');

        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.explorer_class == ExplorerClass::Fighter, 'wrong class');
        assert(stats.level == 1, 'wrong level');
        assert(stats.xp == 0, 'wrong xp');
        assert(stats.temples_conquered == 0, 'wrong temples');

        // Stats must be valid standard array values (sum = 72)
        assert_standard_array(@stats);
    }

    #[test]
    fn test_mint_fighter_hp_and_ac() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        // let stats: ExplorerStats = world.read_model(explorer_id);
        let health: ExplorerHealth = world.read_model(explorer_id);
        let combat: ExplorerCombat = world.read_model(explorer_id);

        // Fighter hit die = 10, CON mod in [-1, +2] → HP in [9, 12]
        assert(health.max_hp >= 9 && health.max_hp <= 12, 'fighter HP out of range');
        assert(health.current_hp == health.max_hp.try_into().unwrap(), 'current_hp = max_hp');
        assert(!health.is_dead, 'should not be dead');

        // Fighter: Chain Mail → AC = 16 (ignores DEX)
        assert(combat.armor_class == 16, 'fighter AC should be 16');
        assert(!combat.second_wind_used, 'second_wind fresh');
        assert(!combat.action_surge_used, 'action_surge fresh');
        assert(combat.spell_slots_1 == 0, 'fighter has no spell slots');
    }

    #[test]
    fn test_mint_fighter_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Longsword, 'fighter weapon: longsword');
        assert(inv.secondary_weapon == WeaponType::None, 'fighter no secondary');
        assert(inv.armor == ArmorType::ChainMail, 'fighter armor: chain mail');
        assert(!inv.has_shield, 'no shield');
        assert(inv.gold == 0, 'start with no gold');
        assert(inv.potions == 0, 'start with no potions');
    }

    #[test]
    fn test_mint_fighter_skills() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        let skills: ExplorerSkills = world.read_model(explorer_id);
        // Fighter always has Athletics
        assert(skills.skills.athletics, 'fighter: athletics auto');
        // Fighter gets exactly one of Perception or Acrobatics (not both, not neither)
        assert(skills.skills.perception || skills.skills.acrobatics, 'fighter: must have 1 optional');
        assert(!(skills.skills.perception && skills.skills.acrobatics), 'fighter: only 1 optional');
        assert(!skills.skills.stealth, 'fighter: no stealth');
        assert(!skills.skills.arcana, 'fighter: no arcana');
        assert(!skills.skills.persuasion, 'fighter: no persuasion');
        assert(skills.expertise_1 == Skill::None, 'no expertise');
        assert(skills.expertise_2 == Skill::None, 'no expertise_2');
    }

    #[test]
    fn test_mint_fighter_position() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        let pos: ExplorerPosition = world.read_model(explorer_id);
        assert(pos.temple_id == 0, 'not in a temple');
        assert(pos.chamber_id == 0, 'not in a chamber');
        assert(!pos.in_combat, 'not in combat');
        assert(pos.combat_monster_id == 0, 'no combat monster');
    }

    // ── Rogue tests ───────────────────────────────────────────────────────────

    #[test]
    fn test_mint_rogue_basic() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let explorer_id = token.mint_explorer(ExplorerClass::Rogue);

        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.explorer_class == ExplorerClass::Rogue, 'wrong class');
        assert_standard_array(@stats);

        let health: ExplorerHealth = world.read_model(explorer_id);
        // Rogue hit die = 8, CON mod in [-1, +2] → HP in [7, 10]
        assert(health.max_hp >= 7 && health.max_hp <= 10, 'rogue HP out of range');

        let combat: ExplorerCombat = world.read_model(explorer_id);
        // Rogue: Leather AC = 11 + DEX mod. DEX mod in [-1, +2] → AC in [10, 13]
        assert(combat.armor_class >= 10 && combat.armor_class <= 13, 'rogue AC out of range');
        assert(combat.spell_slots_1 == 0, 'rogue has no spell slots');
    }

    #[test]
    fn test_mint_rogue_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Rogue);

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Dagger, 'rogue weapon: dagger');
        assert(inv.secondary_weapon == WeaponType::Shortbow, 'rogue secondary: shortbow');
        assert(inv.armor == ArmorType::Leather, 'rogue armor: leather');
    }

    #[test]
    fn test_mint_rogue_skills_and_expertise() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Rogue);

        let skills: ExplorerSkills = world.read_model(explorer_id);
        // Rogue always has Stealth and Acrobatics
        assert(skills.skills.stealth, 'rogue: stealth auto');
        assert(skills.skills.acrobatics, 'rogue: acrobatics auto');
        // Rogue expertise must be non-None and different
        assert(skills.expertise_1 != Skill::None, 'rogue: expertise_1 set');
        assert(skills.expertise_2 != Skill::None, 'rogue: expertise_2 set');
        assert(skills.expertise_1 != skills.expertise_2, 'rogue: expertise unique');
    }

    // ── Wizard tests ──────────────────────────────────────────────────────────

    #[test]
    fn test_mint_wizard_basic() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let explorer_id = token.mint_explorer(ExplorerClass::Wizard);

        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.explorer_class == ExplorerClass::Wizard, 'wrong class');
        assert_standard_array(@stats);

        let health: ExplorerHealth = world.read_model(explorer_id);
        // Wizard hit die = 6, CON mod in [-1, +2] → HP in [5, 8]
        assert(health.max_hp >= 5 && health.max_hp <= 8, 'wizard HP out of range');

        let combat: ExplorerCombat = world.read_model(explorer_id);
        // Wizard: no armor AC = 10 + DEX mod. DEX mod in [-1, +2] → AC in [9, 12]
        assert(combat.armor_class >= 9 && combat.armor_class <= 12, 'wizard AC out of range');
        assert(combat.spell_slots_1 == 2, 'wizard level1 slots = 2');
        assert(combat.spell_slots_2 == 0, 'wizard no level2 slots');
        assert(combat.spell_slots_3 == 0, 'wizard no level3 slots');
    }

    #[test]
    fn test_mint_wizard_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Wizard);

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Staff, 'wizard weapon: staff');
        assert(inv.secondary_weapon == WeaponType::None, 'wizard no secondary');
        assert(inv.armor == ArmorType::None, 'wizard no armor');
    }

    #[test]
    fn test_mint_wizard_skills() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Wizard);

        let skills: ExplorerSkills = world.read_model(explorer_id);
        // Wizard always has Arcana
        assert(skills.skills.arcana, 'wizard: arcana auto');
        // Wizard gets exactly one of Perception or Persuasion
        assert(skills.skills.perception || skills.skills.persuasion, 'wizard: must have 1 optional');
        assert(!(skills.skills.perception && skills.skills.persuasion), 'wizard: only 1 optional');
        assert(!skills.skills.athletics, 'wizard: no athletics');
        assert(!skills.skills.stealth, 'wizard: no stealth');
        assert(skills.expertise_1 == Skill::None, 'no expertise');
    }

    // ── Sequential minting ────────────────────────────────────────────────────

    #[test]
    fn test_sequential_token_ids() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let id1 = token.mint_explorer(ExplorerClass::Fighter);
        let id2 = token.mint_explorer(ExplorerClass::Wizard);
        let id3 = token.mint_explorer(ExplorerClass::Rogue);

        assert(id1 == 1_u128, 'first id should be 1');
        assert(id2 == 2_u128, 'second id should be 2');
        assert(id3 == 3_u128, 'third id should be 3');

        // Verify ERC721 state
        assert(token.total_supply() == 3_u256, 'supply should be 3');
        assert(token.balance_of(caller) == 3_u256, 'balance should be 3');
        assert(token.owner_of(id1.into()) == caller, 'wrong owner id1');
        assert(token.owner_of(id2.into()) == caller, 'wrong owner id2');
        assert(token.owner_of(id3.into()) == caller, 'wrong owner id3');

        // Each explorer has independent state
        let s1: ExplorerStats = world.read_model(id1);
        let s2: ExplorerStats = world.read_model(id2);
        let s3: ExplorerStats = world.read_model(id3);
        assert(s1.explorer_class == ExplorerClass::Fighter, 'id1 should be fighter');
        assert(s2.explorer_class == ExplorerClass::Wizard, 'id2 should be wizard');
        assert(s3.explorer_class == ExplorerClass::Rogue, 'id3 should be rogue');
    }

    // ── rest() tests ──────────────────────────────────────────────────────────

    #[test]
    fn test_rest_restores_hp() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        // Simulate damage by writing model directly
        let mut health: ExplorerHealth = world.read_model(explorer_id);
        let max_hp = health.max_hp;
        health.current_hp = 3;
        world.write_model_test(@health);

        // Rest should restore HP
        token.rest(explorer_id);

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.current_hp == max_hp.try_into().unwrap(), 'HP should be restored');
    }

    #[test]
    fn test_rest_resets_class_resources() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        // Simulate spent class resources
        let mut combat: ExplorerCombat = world.read_model(explorer_id);
        combat.second_wind_used = true;
        combat.action_surge_used = true;
        world.write_model_test(@combat);

        token.rest(explorer_id);

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(!combat.second_wind_used, 'second_wind reset');
        assert(!combat.action_surge_used, 'action_surge reset');
    }

    #[test]
    fn test_rest_resets_wizard_spell_slots() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Wizard);

        // Spend all spell slots
        let mut combat: ExplorerCombat = world.read_model(explorer_id);
        combat.spell_slots_1 = 0;
        world.write_model_test(@combat);

        token.rest(explorer_id);

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(combat.spell_slots_1 == 2, 'wizard level1 slots restored');
    }

    // ── Validation failure tests ──────────────────────────────────────────────

    #[test]
    #[should_panic(expected: ('must choose a class', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_none_class() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token) = setup_world();
        token.mint_explorer(ExplorerClass::None);
    }

    #[test]
    #[should_panic(expected: ('dead explorers cannot rest', 'ENTRYPOINT_FAILED'))]
    fn test_rest_rejects_dead_explorer() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let explorer_id = token.mint_explorer(ExplorerClass::Fighter);

        // Kill the explorer via write_model_test
        let mut health: ExplorerHealth = world.read_model(explorer_id);
        health.is_dead = true;
        health.current_hp = 0;
        world.write_model_test(@health);

        token.rest(explorer_id); // should panic
    }
}
