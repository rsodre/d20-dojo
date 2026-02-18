#[cfg(test)]
mod tests {

    use starknet::ContractAddress;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait,
    };

    use d20::systems::explorer_token::{
        explorer_token, IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
    };
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
    use d20::types::explorer::ExplorerClass;

    // ── Test world setup ──────────────────────────────────────────────────────

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: [
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

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span()),
        ].span()
    }

    // ── Standard array helpers ────────────────────────────────────────────────

    // Standard array [STR=15, DEX=14, CON=13, INT=12, WIS=10, CHA=8]
    fn stats_fighter() -> Span<u8> {
        array![15_u8, 14_u8, 13_u8, 12_u8, 10_u8, 8_u8].span()
    }

    // Standard array optimised for Rogue [STR=8, DEX=15, CON=14, INT=12, WIS=10, CHA=13]
    fn stats_rogue() -> Span<u8> {
        array![8_u8, 15_u8, 14_u8, 12_u8, 10_u8, 13_u8].span()
    }

    // Standard array optimised for Wizard [STR=8, DEX=14, CON=13, INT=15, WIS=12, CHA=10]
    fn stats_wizard() -> Span<u8> {
        array![8_u8, 14_u8, 13_u8, 15_u8, 12_u8, 10_u8].span()
    }

    // ── Fighter tests ─────────────────────────────────────────────────────────

    #[test]
    fn test_mint_fighter_basic() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );

        // ERC-721 token ID starts at 1
        assert(token_id == 1_u256, 'token_id should be 1');

        let explorer_id: u128 = token_id.low;
        let stats: ExplorerStats = world.read_model(explorer_id);

        assert(stats.class == ExplorerClass::Fighter, 'wrong class');
        assert(stats.level == 1, 'wrong level');
        assert(stats.xp == 0, 'wrong xp');
        assert(stats.strength == 15, 'wrong str');
        assert(stats.dexterity == 14, 'wrong dex');
        assert(stats.constitution == 13, 'wrong con');
        assert(stats.intelligence == 12, 'wrong int');
        assert(stats.wisdom == 10, 'wrong wis');
        assert(stats.charisma == 8, 'wrong cha');
        assert(stats.temples_conquered == 0, 'wrong temples');
    }

    #[test]
    fn test_mint_fighter_hp_and_ac() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // STR=15, DEX=14, CON=13 → CON mod = +1, so HP = 10+1 = 11
        // DEX mod = +2 but Chain Mail ignores DEX → AC = 16
        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.max_hp == 11, 'fighter HP should be 11');
        assert(health.current_hp == 11, 'fighter current_hp should be 11');
        assert(!health.is_dead, 'should not be dead');

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(combat.armor_class == 16, 'fighter AC should be 16');
        assert(!combat.second_wind_used, 'second_wind fresh');
        assert(!combat.action_surge_used, 'action_surge fresh');
        assert(combat.spell_slots_1 == 0, 'fighter has no spell slots');
    }

    #[test]
    fn test_mint_fighter_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

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

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(), // choice
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        let skills: ExplorerSkills = world.read_model(explorer_id);
        assert(skills.athletics, 'fighter: athletics auto');
        assert(skills.perception, 'fighter: perception chosen');
        assert(!skills.acrobatics, 'fighter: no acrobatics');
        assert(!skills.stealth, 'fighter: no stealth');
        assert(!skills.arcana, 'fighter: no arcana');
        assert(skills.expertise_1 == Skill::None, 'no expertise');
    }

    #[test]
    fn test_mint_fighter_position() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

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

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // DEX=15 → mod +2, Leather AC = 11+2 = 13
        // CON=14 → mod +2, HP = 8+2 = 10
        let token_id = token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Athletics].span(),
            array![Skill::Stealth, Skill::Perception].span(), // expertise picks
        );
        let explorer_id: u128 = token_id.low;

        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.class == ExplorerClass::Rogue, 'wrong class');
        assert(stats.dexterity == 15, 'wrong dex');

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.max_hp == 10, 'rogue HP should be 10');

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(combat.armor_class == 13, 'rogue AC should be 13');
        assert(combat.spell_slots_1 == 0, 'rogue has no spell slots');
    }

    #[test]
    fn test_mint_rogue_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Athletics].span(),
            array![Skill::Stealth, Skill::Acrobatics].span(),
        );
        let explorer_id: u128 = token_id.low;

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Dagger, 'rogue weapon: dagger');
        assert(inv.secondary_weapon == WeaponType::Shortbow, 'rogue secondary: shortbow');
        assert(inv.armor == ArmorType::Leather, 'rogue armor: leather');
    }

    #[test]
    fn test_mint_rogue_skills_and_expertise() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Athletics].span(),
            array![Skill::Stealth, Skill::Perception].span(),
        );
        let explorer_id: u128 = token_id.low;

        let skills: ExplorerSkills = world.read_model(explorer_id);
        assert(skills.stealth, 'rogue: stealth auto');
        assert(skills.acrobatics, 'rogue: acrobatics auto');
        assert(skills.perception, 'rogue: perception chosen');
        assert(skills.athletics, 'rogue: athletics chosen');
        assert(!skills.arcana, 'rogue: no arcana');
        assert(skills.expertise_1 == Skill::Stealth, 'expertise_1: stealth');
        assert(skills.expertise_2 == Skill::Perception, 'expertise_2: perception');
    }

    // ── Wizard tests ──────────────────────────────────────────────────────────

    #[test]
    fn test_mint_wizard_basic() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // DEX=14 → mod +2, No armor AC = 10+2 = 12
        // CON=13 → mod +1, HP = 6+1 = 7
        let token_id = token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        let stats: ExplorerStats = world.read_model(explorer_id);
        assert(stats.class == ExplorerClass::Wizard, 'wrong class');
        assert(stats.intelligence == 15, 'wrong int');

        let health: ExplorerHealth = world.read_model(explorer_id);
        assert(health.max_hp == 7, 'wizard HP should be 7');

        let combat: ExplorerCombat = world.read_model(explorer_id);
        assert(combat.armor_class == 12, 'wizard AC should be 12');
        assert(combat.spell_slots_1 == 2, 'wizard level1 slots = 2');
        assert(combat.spell_slots_2 == 0, 'wizard no level2 slots');
        assert(combat.spell_slots_3 == 0, 'wizard no level3 slots');
    }

    #[test]
    fn test_mint_wizard_equipment() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        let inv: ExplorerInventory = world.read_model(explorer_id);
        assert(inv.primary_weapon == WeaponType::Staff, 'wizard weapon: staff');
        assert(inv.secondary_weapon == WeaponType::None, 'wizard no secondary');
        assert(inv.armor == ArmorType::None, 'wizard no armor');
    }

    #[test]
    fn test_mint_wizard_skills() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Persuasion].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        let skills: ExplorerSkills = world.read_model(explorer_id);
        assert(skills.arcana, 'wizard: arcana auto');
        assert(skills.persuasion, 'wizard: persuasion chosen');
        assert(!skills.perception, 'wizard: no perception');
        assert(!skills.athletics, 'wizard: no athletics');
        assert(skills.expertise_1 == Skill::None, 'no expertise');
    }

    // ── Sequential minting ────────────────────────────────────────────────────

    #[test]
    fn test_sequential_token_ids() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let id1 = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let id2 = token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let id3 = token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Athletics].span(),
            array![Skill::Stealth, Skill::Acrobatics].span(),
        );

        assert(id1 == 1_u256, 'first id should be 1');
        assert(id2 == 2_u256, 'second id should be 2');
        assert(id3 == 3_u256, 'third id should be 3');

        // Each explorer has independent state
        let s1: ExplorerStats = world.read_model(id1.low);
        let s2: ExplorerStats = world.read_model(id2.low);
        let s3: ExplorerStats = world.read_model(id3.low);
        assert(s1.class == ExplorerClass::Fighter, 'id1 should be fighter');
        assert(s2.class == ExplorerClass::Wizard, 'id2 should be wizard');
        assert(s3.class == ExplorerClass::Rogue, 'id3 should be rogue');
    }

    // ── rest() tests ──────────────────────────────────────────────────────────

    #[test]
    fn test_rest_restores_hp() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

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

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

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

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

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

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        token.mint_explorer(
            ExplorerClass::None,
            stats_fighter(),
            array![].span(),
            array![].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('not standard array', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_invalid_stats() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // All 18s — invalid
        token.mint_explorer(
            ExplorerClass::Fighter,
            array![18_u8, 18_u8, 18_u8, 18_u8, 18_u8, 18_u8].span(),
            array![Skill::Perception].span(),
            array![].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('fighter needs 1 skill choice', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_fighter_wrong_skill_count() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![].span(), // Fighter needs exactly 1
            array![].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('invalid fighter skill choice', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_fighter_wrong_skill() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // Fighter can only pick Perception or Acrobatics
        token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Arcana].span(),
            array![].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('invalid rogue skill choice', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_rogue_wrong_skill() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // Rogue cannot pick Acrobatics (already automatic)... wait, can pick from list
        // Stealth is not in the optional list (it's automatic), so it's invalid
        token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Stealth, Skill::Perception].span(), // Stealth not in optional list
            array![Skill::Stealth, Skill::Acrobatics].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('duplicate expertise choice', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_rogue_duplicate_expertise() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Athletics].span(),
            array![Skill::Stealth, Skill::Stealth].span(), // duplicate
        );
    }

    #[test]
    #[should_panic(expected: ('invalid wizard skill choice', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_wizard_wrong_skill() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        // Wizard can only pick Perception or Persuasion
        token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Athletics].span(),
            array![].span(),
        );
    }

    #[test]
    #[should_panic(expected: ('only rogue gets expertise', 'ENTRYPOINT_FAILED'))]
    fn test_mint_rejects_fighter_with_expertise() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![Skill::Athletics, Skill::Perception].span(), // fighters can't have expertise
        );
    }

    #[test]
    #[should_panic(expected: ('dead explorers cannot rest', 'ENTRYPOINT_FAILED'))]
    fn test_rest_rejects_dead_explorer() {
        let caller: ContractAddress = 'player1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"explorer_token").unwrap();
        let token = IExplorerTokenDispatcher { contract_address };

        let token_id = token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        );
        let explorer_id: u128 = token_id.low;

        // Kill the explorer via write_model_test
        let mut health: ExplorerHealth = world.read_model(explorer_id);
        health.is_dead = true;
        health.current_hp = 0;
        world.write_model_test(@health);

        token.rest(explorer_id); // should panic
    }
}
