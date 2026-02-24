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
        IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
    };
    use d20::d20::models::character::{
        CharacterStats,
        CharacterCombat,
        CharacterInventory,
        CharacterPosition,
        CharacterSkills,
        Skill,
    };
    use d20::d20::types::items::{WeaponType, ArmorType};
    use d20::d20::types::character_class::CharacterClass;
    use d20::tests::mock_vrf::MockVrf;

    // ── Test world setup ──────────────────────────────────────────────────────

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_2",
            resources: [
                TestResource::Model(d20::models::config::m_Config::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterStats::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterCombat::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterInventory::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterPosition::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterSkills::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_CharacterMinted::TEST_CLASS_HASH),
                TestResource::Contract(d20::systems::explorer_token::explorer_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    /// Deploy MockVrf and wire it to explorer_token via dojo_init calldata.
    fn setup_world() -> (dojo::world::WorldStorage, IExplorerTokenDispatcher) {
        let (mock_vrf_address, _) = deploy_syscall(
            MockVrf::TEST_CLASS_HASH, 0, [].span(), false,
        ).unwrap_syscall();

        let contract_defs: Span<ContractDef> = [
            ContractDefTrait::new(@"d20_0_2", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_2")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
        ].span();

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        (world, IExplorerTokenDispatcher { contract_address })
    }

    // ── Helper: verify standard array invariant ───────────────────────────────

    /// Assert each stat value is from [15,14,13,12,10,8].
    fn assert_standard_array(stats: @CharacterStats) {
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

        let character_id = token.mint_explorer(CharacterClass::Fighter);

        // ERC-721 token ID starts at 1
        assert(character_id == 1_u128, 'character_id should be 1');

        // Verify ERC721 state
        assert(token.total_supply() == 1_u256, 'supply should be 1');
        assert(token.balance_of(caller) == 1_u256, 'balance should be 1');
        assert(token.owner_of(character_id.into()) == caller, 'wrong owner');

        let stats: CharacterStats = world.read_model(character_id);
        assert(stats.character_class == CharacterClass::Fighter, 'wrong class');
        assert(stats.level == 1, 'wrong level');
        assert(stats.xp == 0, 'wrong xp');
        assert(stats.dungeons_conquered == 0, 'wrong temples');

        // Stats must be valid standard array values (sum = 72)
        assert_standard_array(@stats);
    }

    #[test]
    fn test_mint_fighter_hp_and_ac() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();

        let character_id = token.mint_explorer(CharacterClass::Fighter);

        let stats: CharacterStats = world.read_model(character_id);
        let combat: CharacterCombat = world.read_model(character_id);

        // Fighter hit die = 10, CON mod in [-1, +2] → HP in [9, 12]
        assert(stats.max_hp >= 9 && stats.max_hp <= 12, 'fighter HP out of range');
        assert(stats.current_hp == stats.max_hp.try_into().unwrap(), 'current_hp = max_hp');
        assert(!stats.is_dead, 'should not be dead');

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
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        let inv: CharacterInventory = world.read_model(character_id);
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
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        let skills: CharacterSkills = world.read_model(character_id);
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
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        let pos: CharacterPosition = world.read_model(character_id);
        assert(pos.dungeon_id == 0, 'not in a temple');
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

        let character_id = token.mint_explorer(CharacterClass::Rogue);

        let stats: CharacterStats = world.read_model(character_id);
        assert(stats.character_class == CharacterClass::Rogue, 'wrong class');
        assert_standard_array(@stats);

        let rogue_stats: CharacterStats = world.read_model(character_id);
        // Rogue hit die = 8, CON mod in [-1, +2] → HP in [7, 10]
        assert(rogue_stats.max_hp >= 7 && rogue_stats.max_hp <= 10, 'rogue HP out of range');

        let combat: CharacterCombat = world.read_model(character_id);
        // Rogue: Leather AC = 11 + DEX mod. DEX mod in [-1, +2] → AC in [10, 13]
        assert(combat.armor_class >= 10 && combat.armor_class <= 13, 'rogue AC out of range');
        assert(combat.spell_slots_1 == 0, 'rogue has no spell slots');
    }

    #[test]
    fn test_mint_rogue_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Rogue);

        let inv: CharacterInventory = world.read_model(character_id);
        assert(inv.primary_weapon == WeaponType::Dagger, 'rogue weapon: dagger');
        assert(inv.secondary_weapon == WeaponType::Shortbow, 'rogue secondary: shortbow');
        assert(inv.armor == ArmorType::Leather, 'rogue armor: leather');
    }

    #[test]
    fn test_mint_rogue_skills_and_expertise() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Rogue);

        let skills: CharacterSkills = world.read_model(character_id);
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

        let character_id = token.mint_explorer(CharacterClass::Wizard);

        let stats: CharacterStats = world.read_model(character_id);
        assert(stats.character_class == CharacterClass::Wizard, 'wrong class');
        assert_standard_array(@stats);

        let wiz_stats: CharacterStats = world.read_model(character_id);
        // Wizard hit die = 6, CON mod in [-1, +2] → HP in [5, 8]
        assert(wiz_stats.max_hp >= 5 && wiz_stats.max_hp <= 8, 'wizard HP out of range');

        let combat: CharacterCombat = world.read_model(character_id);
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
        let character_id = token.mint_explorer(CharacterClass::Wizard);

        let inv: CharacterInventory = world.read_model(character_id);
        assert(inv.primary_weapon == WeaponType::Staff, 'wizard weapon: staff');
        assert(inv.secondary_weapon == WeaponType::None, 'wizard no secondary');
        assert(inv.armor == ArmorType::None, 'wizard no armor');
    }

    #[test]
    fn test_mint_wizard_skills() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Wizard);

        let skills: CharacterSkills = world.read_model(character_id);
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

        let id1 = token.mint_explorer(CharacterClass::Fighter);
        let id2 = token.mint_explorer(CharacterClass::Wizard);
        let id3 = token.mint_explorer(CharacterClass::Rogue);

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
        let s1: CharacterStats = world.read_model(id1);
        let s2: CharacterStats = world.read_model(id2);
        let s3: CharacterStats = world.read_model(id3);
        assert(s1.character_class == CharacterClass::Fighter, 'id1 should be fighter');
        assert(s2.character_class == CharacterClass::Wizard, 'id2 should be wizard');
        assert(s3.character_class == CharacterClass::Rogue, 'id3 should be rogue');
    }

    // ── rest() tests ──────────────────────────────────────────────────────────

    #[test]
    fn test_rest_restores_hp() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        // Simulate damage by writing model directly
        let mut stats: CharacterStats = world.read_model(character_id);
        let max_hp = stats.max_hp;
        stats.current_hp = 3;
        world.write_model_test(@stats);

        // Rest should restore HP
        token.rest(character_id);

        let stats: CharacterStats = world.read_model(character_id);
        assert(stats.current_hp == max_hp.try_into().unwrap(), 'HP should be restored');
    }

    #[test]
    fn test_rest_resets_class_resources() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        // Simulate spent class resources
        let mut combat: CharacterCombat = world.read_model(character_id);
        combat.second_wind_used = true;
        combat.action_surge_used = true;
        world.write_model_test(@combat);

        token.rest(character_id);

        let combat: CharacterCombat = world.read_model(character_id);
        assert(!combat.second_wind_used, 'second_wind reset');
        assert(!combat.action_surge_used, 'action_surge reset');
    }

    #[test]
    fn test_rest_resets_wizard_spell_slots() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Wizard);

        // Spend all spell slots
        let mut combat: CharacterCombat = world.read_model(character_id);
        combat.spell_slots_1 = 0;
        world.write_model_test(@combat);

        token.rest(character_id);

        let combat: CharacterCombat = world.read_model(character_id);
        assert(combat.spell_slots_1 == 2, 'wizard level1 slots restored');
    }

    // ── Validation failure tests ──────────────────────────────────────────────

    #[test]
    #[should_panic(expected: ('must choose a class', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_none_class() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token) = setup_world();
        token.mint_explorer(CharacterClass::None);
    }

    #[test]
    #[should_panic(expected: ('dead characters cannot rest', 'ENTRYPOINT_FAILED'))]
    fn test_rest_rejects_dead_explorer() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token) = setup_world();
        let character_id = token.mint_explorer(CharacterClass::Fighter);

        // Kill the character via write_model_test
        let mut stats: CharacterStats = world.read_model(character_id);
        stats.is_dead = true;
        stats.current_hp = 0;
        world.write_model_test(@stats);

        token.rest(character_id); // should panic
    }
}
