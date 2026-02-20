#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait};

    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills
    };
    use d20::models::temple::{
        TempleState, Chamber, ChamberExit, MonsterInstance,
        FallenExplorer, ChamberFallenCount, ExplorerTempleProgress
    };
    use d20::types::index::{ChamberType};
    use d20::types::items::{WeaponType, ArmorType};
    use d20::types::explorer_class::ExplorerClass;
    use d20::types::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, mint_wizard, assert_explorer_dead,
    };
    use d20::systems::explorer_token::{IExplorerTokenDispatcherTrait};
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

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

    // ═══════════════════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════════════════
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
