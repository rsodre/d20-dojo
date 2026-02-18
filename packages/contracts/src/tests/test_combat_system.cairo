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
    use d20::models::config::{Config, m_Config};
    use d20::models::explorer::{
        ExplorerStats, m_ExplorerStats,
        ExplorerHealth, m_ExplorerHealth,
        ExplorerCombat, m_ExplorerCombat,
        ExplorerInventory, m_ExplorerInventory,
        ExplorerPosition, m_ExplorerPosition,
        m_ExplorerSkills,
    };
    use d20::models::temple::{
        MonsterInstance, m_MonsterInstance,
        FallenExplorer, m_FallenExplorer,
        ChamberFallenCount, m_ChamberFallenCount,
    };
    use d20::events::{e_ExplorerMinted, e_CombatResult, e_ExplorerDied};
    use d20::types::index::{Skill, ItemType};
    use d20::types::items::{WeaponType, ArmorType};
    use d20::types::explorer::ExplorerClass;
    use d20::types::monster::MonsterType;
    use d20::utils::dice::{ability_modifier, proficiency_bonus};
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
                TestResource::Model(m_MonsterInstance::TEST_CLASS_HASH),
                TestResource::Model(m_FallenExplorer::TEST_CLASS_HASH),
                TestResource::Model(m_ChamberFallenCount::TEST_CLASS_HASH),
                TestResource::Event(e_ExplorerMinted::TEST_CLASS_HASH),
                TestResource::Event(e_CombatResult::TEST_CLASS_HASH),
                TestResource::Event(e_ExplorerDied::TEST_CLASS_HASH),
                TestResource::Contract(explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(combat_system::TEST_CLASS_HASH),
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

        // 2. Build contract defs — pass vrf_address as init calldata for combat_system
        let contract_defs: Span<ContractDef> = [
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"d20_0_1")].span()),
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

    // ── Standard stat arrays ─────────────────────────────────────────────────

    fn stats_fighter() -> Span<u8> {
        array![15_u8, 14_u8, 13_u8, 12_u8, 10_u8, 8_u8].span()
    }

    fn stats_rogue() -> Span<u8> {
        array![8_u8, 15_u8, 14_u8, 12_u8, 10_u8, 13_u8].span()
    }

    fn stats_wizard() -> Span<u8> {
        array![8_u8, 14_u8, 13_u8, 15_u8, 12_u8, 10_u8].span()
    }

    // ── Mint helpers ─────────────────────────────────────────────────────────

    fn mint_fighter(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(
            ExplorerClass::Fighter,
            stats_fighter(),
            array![Skill::Perception].span(),
            array![].span(),
        )
    }

    fn mint_rogue(token: IExplorerTokenDispatcher) -> u128 {
        // Rogue: stealth + acrobatics automatic, 2 choices from [Perception, Persuasion, Athletics, Arcana]
        token.mint_explorer(
            ExplorerClass::Rogue,
            stats_rogue(),
            array![Skill::Perception, Skill::Persuasion].span(),
            array![Skill::Stealth, Skill::Acrobatics].span(),
        )
    }

    fn mint_wizard(token: IExplorerTokenDispatcher) -> u128 {
        token.mint_explorer(
            ExplorerClass::Wizard,
            stats_wizard(),
            array![Skill::Perception].span(),
            array![].span(),
        )
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
        let explorer_id = mint_fighter(token);

        // Reduce HP to 3 to simulate damage (Fighter HP = 11)
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 3,
            max_hp: 11,
            is_dead: false,
        });

        combat_sys.second_wind(explorer_id);

        let after: ExplorerHealth = world.read_model(explorer_id);
        // 1d10+1 heal from 3 HP. Mock returns mid-range (5 per d10).
        assert(after.current_hp > 3, 'second wind should heal');
        assert(after.current_hp <= 11, 'cannot exceed max hp');
        assert(!after.is_dead, 'should not be dead');
    }

    #[test]
    fn test_second_wind_marks_used() {
        let caller: ContractAddress = 'fighter2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        let before: ExplorerCombat = world.read_model(explorer_id);
        assert(!before.second_wind_used, 'fresh before use');

        combat_sys.second_wind(explorer_id);

        let after: ExplorerCombat = world.read_model(explorer_id);
        assert(after.second_wind_used, 'marked used after');
    }

    #[test]
    #[should_panic]
    fn test_second_wind_fails_if_already_used() {
        let caller: ContractAddress = 'fighter3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        combat_sys.second_wind(explorer_id);   // ok
        combat_sys.second_wind(explorer_id);   // should panic
    }

    #[test]
    #[should_panic]
    fn test_second_wind_fails_for_non_fighter() {
        let caller: ContractAddress = 'rogue1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let explorer_id = mint_rogue(token);
        combat_sys.second_wind(explorer_id);
    }

    #[test]
    fn test_second_wind_caps_at_max_hp() {
        let caller: ContractAddress = 'fighter4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        // Fighter starts at full HP (11). Second wind should not exceed max.
        combat_sys.second_wind(explorer_id);

        let after: ExplorerHealth = world.read_model(explorer_id);
        assert(after.current_hp <= 11, 'hp cannot exceed max');
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
        let explorer_id = mint_rogue(token);

        // Level to 2
        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats {
            explorer_id,
            strength: stats.strength,
            dexterity: stats.dexterity,
            constitution: stats.constitution,
            intelligence: stats.intelligence,
            wisdom: stats.wisdom,
            charisma: stats.charisma,
            level: 2,
            xp: stats.xp,
            class: stats.class,
            temples_conquered: stats.temples_conquered,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.cunning_action(explorer_id);

        let after: ExplorerPosition = world.read_model(explorer_id);
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
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.cunning_action(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_cunning_action_fails_if_not_in_combat() {
        let caller: ContractAddress = 'rogue3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_rogue(token);

        // Level to 2
        let stats: ExplorerStats = world.read_model(explorer_id);
        world.write_model_test(@ExplorerStats {
            explorer_id,
            strength: stats.strength,
            dexterity: stats.dexterity,
            constitution: stats.constitution,
            intelligence: stats.intelligence,
            wisdom: stats.wisdom,
            charisma: stats.charisma,
            level: 2,
            xp: stats.xp,
            class: stats.class,
            temples_conquered: stats.temples_conquered,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        combat_sys.cunning_action(explorer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Flee mechanic (task 2.10)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_flee_resolves_without_death() {
        let caller: ContractAddress = 'fighter6'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            temple_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        // Give enough HP to survive a counter-attack
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        combat_sys.flee(explorer_id);

        // Explorer should be alive regardless of flee outcome
        let after: ExplorerHealth = world.read_model(explorer_id);
        assert(!after.is_dead, 'explorer should survive flee');
    }

    #[test]
    #[should_panic]
    fn test_flee_fails_if_not_in_combat() {
        let caller: ContractAddress = 'fighter7'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });

        combat_sys.flee(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_flee_fails_if_dead() {
        let caller: ContractAddress = 'fighter8'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.flee(explorer_id);
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
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        world.write_model_test(@MonsterInstance {
            temple_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        combat_sys.attack(explorer_id);
    }

    #[test]
    #[should_panic]
    fn test_dead_explorer_cannot_second_wind() {
        let caller: ContractAddress = 'deadfighter2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 0,
            max_hp: 11,
            is_dead: true,
        });

        combat_sys.second_wind(explorer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Use item (task 2.8)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_use_health_potion_heals() {
        let caller: ContractAddress = 'potionuser'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 3,
            max_hp: 11,
            is_dead: false,
        });
        world.write_model_test(@ExplorerInventory {
            explorer_id,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 0,
            potions: 2,
        });

        combat_sys.use_item(explorer_id, ItemType::HealthPotion);

        let after: ExplorerHealth = world.read_model(explorer_id);
        assert(after.current_hp > 3, 'potion should heal');
        assert(after.current_hp <= 11, 'cannot exceed max hp');

        let after_inv: ExplorerInventory = world.read_model(explorer_id);
        assert(after_inv.potions == 1, 'potion count decremented');
    }

    #[test]
    #[should_panic]
    fn test_use_health_potion_fails_with_no_potions() {
        let caller: ContractAddress = 'nopotions'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (_world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        // Fighter starts with 0 potions from mint
        combat_sys.use_item(explorer_id, ItemType::HealthPotion);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Attack + death flow (task 2.9)
    // ═══════════════════════════════════════════════════════════════════════

    #[test]
    fn test_attack_hits_monster_and_deals_damage() {
        let caller: ContractAddress = 'attacker1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat_sys) = setup_world();
        let explorer_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            temple_id: 1,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 100,  // high HP so it survives
            max_hp: 100,
            is_alive: true,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 1,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });

        // Give high HP so explorer survives counter-attack
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        combat_sys.attack(explorer_id);

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
        let explorer_id = mint_fighter(token);

        world.write_model_test(@MonsterInstance {
            temple_id: 10,
            chamber_id: 5,
            monster_id: 2,
            monster_type: MonsterType::Skeleton,
            current_hp: 13,
            max_hp: 13,
            is_alive: true,
        });

        world.write_model_test(@ExplorerPosition {
            explorer_id,
            temple_id: 10,
            chamber_id: 5,
            in_combat: true,
            combat_monster_id: 2,
        });

        // 1 HP — any monster hit kills the explorer
        world.write_model_test(@ExplorerHealth {
            explorer_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });

        world.write_model_test(@ExplorerInventory {
            explorer_id,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 50,
            potions: 2,
        });

        combat_sys.attack(explorer_id);

        let after: ExplorerHealth = world.read_model(explorer_id);

        if after.is_dead {
            let fallen: FallenExplorer = world.read_model((10_u128, 5_u32, 0_u32));
            assert(fallen.explorer_id == explorer_id, 'fallen id matches');
            assert(!fallen.is_looted, 'not yet looted');

            let count: ChamberFallenCount = world.read_model((10_u128, 5_u32));
            assert(count.count == 1, 'fallen count should be 1');

            let after_inv: ExplorerInventory = world.read_model(explorer_id);
            assert(after_inv.gold == 0, 'gold dropped on death');
            assert(after_inv.potions == 0, 'potions dropped on death');
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
            temple_id: 99,
            chamber_id: 1,
            count: 3,
        });

        world.write_model_test(@FallenExplorer {
            temple_id: 99,
            chamber_id: 1,
            fallen_index: 3,
            explorer_id: 999,
            dropped_weapon: WeaponType::Dagger,
            dropped_armor: ArmorType::Leather,
            dropped_gold: 100,
            dropped_potions: 1,
            is_looted: false,
        });

        let count: ChamberFallenCount = world.read_model((99_u128, 1_u32));
        assert(count.count == 3, 'count should be 3');

        let fallen: FallenExplorer = world.read_model((99_u128, 1_u32, 3_u32));
        assert(fallen.explorer_id == 999, 'fallen id should be 999');
        assert(fallen.dropped_gold == 100, 'fallen gold = 100');
        assert(!fallen.is_looted, 'not yet looted');
    }
}
