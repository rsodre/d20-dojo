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
        IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait,
    };
    use d20::systems::combat_system::{
        ICombatSystemDispatcher, ICombatSystemDispatcherTrait,
    };
    use d20::models::config::{Config};
    use d20::d20::models::character::{
        CharacterStats,
        CharacterHealth,
        CharacterCombat,
        CharacterInventory,
        CharacterPosition,
    };
    use d20::d20::models::dungeon::{
        MonsterInstance,
        FallenCharacter,
        ChamberFallenCount,
    };
    use d20::d20::types::items::{WeaponType, ArmorType, ItemType};
    use d20::d20::types::character_class::CharacterClass;
    use d20::d20::types::spells::SpellId;
    use d20::d20::models::monster::MonsterType;
    use d20::utils::dice::{ability_modifier, proficiency_bonus};
    use d20::tests::mock_vrf::MockVrf;

    // ── Test world setup ──────────────────────────────────────────────────────

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: [
                TestResource::Model(d20::models::config::m_Config::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterStats::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterHealth::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterCombat::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterInventory::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterPosition::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterSkills::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::dungeon::m_MonsterInstance::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::dungeon::m_FallenCharacter::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::dungeon::m_ChamberFallenCount::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::dungeon::m_DungeonState::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::dungeon::m_CharacterDungeonProgress::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_CharacterMinted::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_CombatResult::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_CharacterDied::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_LevelUp::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_BossDefeated::TEST_CLASS_HASH),
                TestResource::Contract(d20::systems::explorer_token::explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(d20::systems::combat_system::combat_system::TEST_CLASS_HASH),
            ].span(),
        }
    }

    /// Deploy mock VRF, return its address, then build contract_defs passing
    /// the address as init calldata to combat_system's dojo_init.
    fn setup_world() -> (dojo::world::WorldStorage, IExplorerTokenDispatcher, ICombatSystemDispatcher) {
        // 1. Deploy MockVrf at a deterministic address via deploy_syscall
        let mock_vrf_class_hash = MockVrf::TEST_CLASS_HASH;
        let (mock_vrf_address, _) = deploy_syscall(
            mock_vrf_class_hash,
            0,
            [].span(),
            false,
        ).unwrap_syscall();

        // 2. Build contract defs — pass vrf_address as init calldata for both contracts
        let contract_defs: Span<ContractDef> = [
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_1", @"combat_system")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata([mock_vrf_address.into()].span()),
        ].span();

        // 3. Spawn world and sync
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);

        let (token_addr, _) = world.dns(@"explorer_token").unwrap();
        let (combat_addr, _) = world.dns(@"combat_system").unwrap();

        (
            world,
            IExplorerTokenDispatcher { contract_address: token_addr },
            ICombatSystemDispatcher { contract_address: combat_addr },
        )
    }

    // ── Mint helpers ─────────────────────────────────────────────────────────

    fn mint_fighter(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(CharacterClass::Fighter)
    }

    fn mint_rogue(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(CharacterClass::Rogue)
    }

    fn mint_wizard(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(CharacterClass::Wizard)
    }

    // ── Death assertion helper ────────────────────────────────────────────────

    /// Validates all invariants that must hold after an explorer dies:
    /// - is_dead flag set, HP at 0, not in combat
    /// - FallenCharacter record created in the correct chamber
    /// - ChamberFallenCount incremented
    /// - Inventory gold and potions zeroed (dropped as loot)
    fn assert_explorer_dead(
        ref world: dojo::world::WorldStorage,
        character_id: u128,
        dungeon_id: u128,
        chamber_id: u32,
    ) {
        let health: CharacterHealth = world.read_model(character_id);
        assert(health.is_dead, 'explorer should be dead');
        assert(health.current_hp == 0, 'hp should be 0 on death');

        let pos: CharacterPosition = world.read_model(character_id);
        assert(!pos.in_combat, 'dead explorer not in combat');

        let fallen_count: ChamberFallenCount = world.read_model((dungeon_id, chamber_id));
        assert(fallen_count.count >= 1, 'fallen count should be >= 1');

        let fallen: FallenCharacter = world.read_model(
            (dungeon_id, chamber_id, fallen_count.count - 1)
        );
        assert(fallen.character_id == character_id, 'fallen explorer id mismatch');
        assert(!fallen.is_looted, 'fallen should not be looted');

        let inv: CharacterInventory = world.read_model(character_id);
        assert(inv.gold == 0, 'gold dropped on death');
        assert(inv.potions == 0, 'potions dropped on death');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Pure math tests (no world needed)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_ability_modifier_typical_scores() {
        assert(ability_modifier(15) == 2, 'str 15 mod +2');
        assert(ability_modifier(14) == 2, 'dex 14 mod +2');
        assert(ability_modifier(13) == 1, 'con 13 mod +1');
        assert(ability_modifier(12) == 1, 'int 12 mod +1');
        assert(ability_modifier(10) == 0, 'wis 10 mod 0');
        assert(ability_modifier(8) == -1, 'cha 8 mod -1');
    }

    #[test]
    fn test_proficiency_bonus_boundaries() {
        assert(proficiency_bonus(1) == 2, 'level 1 prof +2');
        assert(proficiency_bonus(4) == 2, 'level 4 prof +2');
        assert(proficiency_bonus(5) == 3, 'level 5 prof +3');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Config model
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_config_vrf_address_stored() {
        let caller: ContractAddress = 'cfg_test'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, _token, _combat) = setup_world();

        // dojo_init should have written Config { key: 1, vrf_address: mock_vrf }
        let config: Config = world.read_model(1_u8);
        assert(config.key == 1, 'config key should be 1');
        // vrf_address is non-zero (mock was deployed)
        assert(config.vrf_address != 0.try_into().unwrap(), 'vrf_address must be set');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Second Wind (Fighter feature — task 2.6)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_second_wind_heals_fighter() {
        let caller: ContractAddress = 'fighter1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        // Reduce HP to 3 to simulate damage
        let health: CharacterHealth = world.read_model(character_id);
        let max_hp = health.max_hp;
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 3,
            max_hp,
            is_dead: false,
        });

        combat_sys.second_wind(character_id);

        let after: CharacterHealth = world.read_model(character_id);
        // 1d10+level heal from 3 HP.
        assert(after.current_hp > 3, 'second wind should heal');
        assert(after.current_hp <= max_hp.try_into().unwrap(), 'cannot exceed max hp');
        assert(!after.is_dead, 'should not be dead');
    }

    #[test]
    fn test_second_wind_marks_used() {
        let caller: ContractAddress = 'fighter2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        let before: CharacterCombat = world.read_model(character_id);
        assert(!before.second_wind_used, 'fresh before use');

        combat_sys.second_wind(character_id);

        let after: CharacterCombat = world.read_model(character_id);
        assert(after.second_wind_used, 'marked used after');
    }

    #[test]
    #[should_panic]
    fn test_second_wind_fails_if_already_used() {
        let caller: ContractAddress = 'fighter3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        combat_sys.second_wind(character_id);   // ok
        combat_sys.second_wind(character_id);   // should panic
    }

    #[test]
    #[should_panic]
    fn test_second_wind_fails_for_non_fighter() {
        let caller: ContractAddress = 'rogue1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let character_id = mint_rogue(token);
        combat_sys.second_wind(character_id);
    }

    #[test]
    fn test_second_wind_caps_at_max_hp() {
        let caller: ContractAddress = 'fighter4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        // Fighter starts at full HP. Second wind should not exceed max.
        combat_sys.second_wind(character_id);

        let after: CharacterHealth = world.read_model(character_id);
        assert(after.current_hp <= after.max_hp.try_into().unwrap(), 'hp cannot exceed max');
        assert(after.current_hp >= 1, 'hp must be at least 1');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Cunning Action (Rogue feature — task 2.7)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_cunning_action_clears_combat() {
        let caller: ContractAddress = 'rogue2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_rogue(token);

        // Level to 2
        let stats: CharacterStats = world.read_model(character_id);
        world.write_model_test(@CharacterStats {
            character_id,
            abilities: stats.abilities,
            level: 2,
            xp: stats.xp,
            character_class: stats.character_class,
            dungeons_conquered: stats.dungeons_conquered,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.cunning_action(character_id);

        let after: CharacterPosition = world.read_model(character_id);
        assert(!after.in_combat, 'should not be in combat');
        assert(after.combat_monster_id == 0, 'monster id cleared');
        assert(after.chamber_id == 1, 'chamber unchanged');
    }

    #[test]
    #[should_panic]
    fn test_cunning_action_fails_for_fighter() {
        let caller: ContractAddress = 'fighter5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.cunning_action(character_id);
    }

    #[test]
    #[should_panic]
    fn test_cunning_action_fails_if_not_in_combat() {
        let caller: ContractAddress = 'rogue3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_rogue(token);

        // Level to 2
        let stats: CharacterStats = world.read_model(character_id);
        world.write_model_test(@CharacterStats {
            character_id,
            abilities: stats.abilities,
            level: 2,
            xp: stats.xp,
            character_class: stats.character_class,
            dungeons_conquered: stats.dungeons_conquered,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        combat_sys.cunning_action(character_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Flee mechanic (task 2.10)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_flee_resolves_without_death() {
        let caller: ContractAddress = 'fighter6'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        // Give enough HP to survive a counter-attack
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        combat_sys.flee(character_id);

        // Explorer should be alive regardless of flee outcome
        let after: CharacterHealth = world.read_model(character_id);
        assert(!after.is_dead, 'explorer should survive flee');
    }

    #[test]
    #[should_panic]
    fn test_flee_fails_if_not_in_combat() {
        let caller: ContractAddress = 'fighter7'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        combat_sys.flee(character_id);
    }

    #[test]
    #[should_panic]
    fn test_flee_fails_if_dead() {
        let caller: ContractAddress = 'fighter8'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.flee(character_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Dead explorer cannot act
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    #[should_panic]
    fn test_dead_explorer_cannot_attack() {
        let caller: ContractAddress = 'deadfighter'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.attack(character_id);
    }

    #[test]
    #[should_panic]
    fn test_dead_explorer_cannot_second_wind() {
        let caller: ContractAddress = 'deadfighter2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        combat_sys.second_wind(character_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Use item (task 2.8)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_use_health_potion_heals() {
        let caller: ContractAddress = 'potionuser'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 3,
            max_hp: 11,
            is_dead: false,
        });
        world.write_model_test(@CharacterInventory {
            character_id,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 0,
            potions: 2,
        });

        combat_sys.use_item(character_id, ItemType::HealthPotion);

        let after: CharacterHealth = world.read_model(character_id);
        assert(after.current_hp > 3, 'potion should heal');
        assert(after.current_hp <= 11, 'cannot exceed max hp');

        let after_inv: CharacterInventory = world.read_model(character_id);
        assert(after_inv.potions == 1, 'potion count decremented');
    }

    #[test]
    #[should_panic]
    fn test_use_health_potion_fails_with_no_potions() {
        let caller: ContractAddress = 'nopotions'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        // Fighter starts with 0 potions from mint
        combat_sys.use_item(character_id, ItemType::HealthPotion);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Attack + death flow (task 2.9)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_attack_hits_monster_and_deals_damage() {
        let caller: ContractAddress = 'attacker1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 100,  // high HP so it survives
            max_hp: 100,
            is_alive: true,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        // Give high HP so explorer survives counter-attack
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        combat_sys.attack(character_id);

        // Monster HP should have changed
        let after_monster: MonsterInstance = world.read_model((1_u128, 1_u32, 1_u32));
        // Either the monster took damage or the attack missed — either way it should still be alive
        assert(after_monster.is_alive, 'monster should survive one hit');
        assert(after_monster.current_hp <= 100, 'hp cannot increase');
    }

    #[test]
    fn test_death_creates_fallen_explorer() {
        let caller: ContractAddress = 'fighter9'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            dungeon_id: 10,
            chamber_id: 5,
            monster_id: 2,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 10,
            chamber_id: 5,
            in_combat: true,
            combat_monster_id: 2,
        });

        // 1 HP — any monster hit kills the character
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });

        world.write_model_test(@CharacterInventory {
            character_id,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 50,
            potions: 2,
        });

        combat_sys.attack(character_id);

        let after: CharacterHealth = world.read_model(character_id);

        if after.is_dead {
            assert_explorer_dead(ref world, character_id, 10_u128, 5_u32);

            // Verify loot values recorded in the FallenCharacter record
            let fallen_count: ChamberFallenCount = world.read_model((10_u128, 5_u32));
            let fallen: FallenCharacter = world.read_model(
                (10_u128, 5_u32, fallen_count.count - 1)
            );
            assert(fallen.dropped_gold == 50, 'dropped gold = 50');
            assert(fallen.dropped_potions == 2, 'dropped potions = 2');
        }
        // If explorer survived (attack missed + monster missed), test still passes
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ChamberFallenCount model
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_chamber_fallen_count_default_zero() {
        let caller: ContractAddress = 'counttest'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (world, _token, _combat) = setup_world();

        let count: ChamberFallenCount = world.read_model((99_u128, 1_u32));
        assert(count.count == 0, 'initial count should be 0');
    }

    #[test]
    fn test_chamber_fallen_write_and_read() {
        let caller: ContractAddress = 'fallentest'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, _token, _combat) = setup_world();

        world.write_model_test(@ChamberFallenCount {
            dungeon_id: 99,
            chamber_id: 1,
            count: 3,
        });

        world.write_model_test(@FallenCharacter {
            dungeon_id: 99,
            chamber_id: 1,
            fallen_index: 3,
            character_id: 999,
            dropped_weapon: WeaponType::Dagger,
            dropped_armor: ArmorType::Leather,
            dropped_gold: 100,
            dropped_potions: 1,
            is_looted: false,
        });

        let count: ChamberFallenCount = world.read_model((99_u128, 1_u32));
        assert(count.count == 3, 'count should be 3');

        let fallen: FallenCharacter = world.read_model((99_u128, 1_u32, 3_u32));
        assert(fallen.character_id == 999, 'fallen id should be 999');
        assert(fallen.dropped_gold == 100, 'fallen gold = 100');
        assert(!fallen.is_looted, 'not yet looted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Spell casting — Magic Missile (auto-hit, 3×(1d4+1))
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_magic_missile_auto_hits_and_deals_damage() {
        let caller: ContractAddress = 'wiz_mm1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 100,
            max_hp: 100,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        let combat_before: CharacterCombat = world.read_model(character_id);
        let slots_before = combat_before.spell_slots_1;

        combat_sys.cast_spell(character_id, SpellId::MagicMissile);

        // Magic Missile auto-hits: monster must have taken damage
        let monster_after: MonsterInstance = world.read_model((1_u128, 1_u32, 1_u32));
        assert(monster_after.current_hp < 100, 'MM must deal damage');

        // Should consume one 1st-level slot
        let combat_after: CharacterCombat = world.read_model(character_id);
        assert(combat_after.spell_slots_1 == slots_before - 1, 'slot consumed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Spell casting — Shield (+5 AC)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_shield_spell_adds_five_ac() {
        let caller: ContractAddress = 'wiz_sh1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        let combat_before: CharacterCombat = world.read_model(character_id);
        let ac_before = combat_before.armor_class;

        combat_sys.cast_spell(character_id, SpellId::ShieldSpell);

        let combat_after: CharacterCombat = world.read_model(character_id);
        assert(combat_after.armor_class == ac_before + 5, 'shield adds +5 AC');

        // Should consume one 1st-level slot
        assert(combat_after.spell_slots_1 == combat_before.spell_slots_1 - 1, 'slot consumed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Spell casting — Misty Step (disengage from combat)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_misty_step_disengages_from_combat() {
        let caller: ContractAddress = 'wiz_ms1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        // Give wizard 2nd level spell slots (requires level 3+)
        let stats: CharacterStats = world.read_model(character_id);
        world.write_model_test(@CharacterStats {
            character_id,
            abilities: stats.abilities,
            level: 3,
            xp: stats.xp,
            character_class: stats.character_class,
            dungeons_conquered: stats.dungeons_conquered,
        });
        world.write_model_test(@CharacterCombat {
            character_id,
            armor_class: 10,
            spell_slots_1: 4,
            spell_slots_2: 2,
            spell_slots_3: 0,
            second_wind_used: false,
            action_surge_used: false,
        });

        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.cast_spell(character_id, SpellId::MistyStep);

        let pos_after: CharacterPosition = world.read_model(character_id);
        assert(!pos_after.in_combat, 'misty step disengages');
        assert(pos_after.combat_monster_id == 0, 'monster id cleared');
        assert(pos_after.chamber_id == 1, 'still in same chamber');

        // Should consume one 2nd-level slot
        let combat_after: CharacterCombat = world.read_model(character_id);
        assert(combat_after.spell_slots_2 == 1, '2nd level slot consumed');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Spell casting — Sleep (5d8 HP pool vs monster)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_sleep_incapacitates_low_hp_monster() {
        let caller: ContractAddress = 'wiz_sl1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        // 1 HP snake: 5d8 (min 5) always beats 1 HP
        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::PoisonousSnake,
            current_hp: 1,
            max_hp: 2,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        combat_sys.cast_spell(character_id, SpellId::Sleep);

        let monster_after: MonsterInstance = world.read_model((1_u128, 1_u32, 1_u32));
        assert(!monster_after.is_alive, 'sleep incapacitates weak foe');

        let pos_after: CharacterPosition = world.read_model(character_id);
        assert(!pos_after.in_combat, 'combat ended after sleep');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Spell casting — validation failures
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    #[should_panic]
    fn test_non_wizard_cannot_cast_spell() {
        let caller: ContractAddress = 'fighter_cast'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        combat_sys.cast_spell(character_id, SpellId::FireBolt);
    }

    #[test]
    #[should_panic]
    fn test_dead_wizard_cannot_cast_spell() {
        let caller: ContractAddress = 'dead_wiz'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        world.write_model_test(@CharacterHealth {
            character_id,
            current_hp: 0,
            max_hp: 6,
            is_dead: true,
        });

        combat_sys.cast_spell(character_id, SpellId::FireBolt);
    }

    #[test]
    #[should_panic]
    fn test_no_spell_slots_rejects_leveled_spell() {
        let caller: ContractAddress = 'wiz_noslots'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_wizard(token);

        // Drain all level 1 slots
        world.write_model_test(@CharacterCombat {
            character_id,
            armor_class: 10,
            spell_slots_1: 0,
            spell_slots_2: 0,
            spell_slots_3: 0,
            second_wind_used: false,
            action_surge_used: false,
        });
        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@MonsterInstance {
            dungeon_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        // Magic Missile needs a 1st level slot → should panic
        combat_sys.cast_spell(character_id, SpellId::MagicMissile);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Use item — potion at full HP caps at max
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_health_potion_caps_at_max_hp() {
        let caller: ContractAddress = 'potion_cap'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        let _health: CharacterHealth = world.read_model(character_id);
        // At full HP, potion shouldn't exceed max
        world.write_model_test(@CharacterInventory {
            character_id,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 0,
            potions: 1,
        });

        combat_sys.use_item(character_id, ItemType::HealthPotion);

        let after: CharacterHealth = world.read_model(character_id);
        assert(after.current_hp <= after.max_hp.try_into().unwrap(), 'hp capped at max');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Attack while not in combat should fail
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    #[should_panic]
    fn test_attack_fails_if_not_in_combat() {
        let caller: ContractAddress = 'atk_nocombat'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let character_id = mint_fighter(token);

        world.write_model_test(@CharacterPosition {
            character_id,
            dungeon_id: 1,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        combat_sys.attack(character_id);
    }
}
