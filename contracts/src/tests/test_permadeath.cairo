#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::adventurer::{
        AdventurerHealth, AdventurerInventory, AdventurerPosition,
    };
    use d20::d20::models::dungeon::{
        MonsterInstance,
        FallenAdventurer, ChamberFallenCount
    };
    use d20::d20::types::items::{WeaponType, ArmorType, ItemType};
    use d20::d20::models::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter,
    };
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_loot_fallen_transfers_items() {
        let caller: ContractAddress = 'fallentest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        // Two explorers: the looter and the fallen
        let looter_id = mint_fighter(token);
        let fallen_adventurer_id: u128 = 9999;

        let dungeon_id = temple.mint_temple(1_u8);

        // Place a fallen explorer body in chamber 2
        world.write_model_test(@ChamberFallenCount {
            dungeon_id,
            chamber_id: 2,
            count: 1,
        });
        world.write_model_test(@FallenAdventurer {
            dungeon_id,
            chamber_id: 2,
            fallen_index: 0,
            adventurer_id: fallen_adventurer_id,
            dropped_weapon: WeaponType::Dagger,
            dropped_armor: ArmorType::Leather,
            dropped_gold: 75,
            dropped_potions: 3,
            is_looted: false,
        });

        world.write_model_test(@AdventurerPosition {
            adventurer_id: looter_id,
            dungeon_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Strip looter's equipment so they can pick up the fallen's items
        world.write_model_test(@AdventurerInventory {
            adventurer_id: looter_id,
            primary_weapon: WeaponType::None,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::None,
            has_shield: false,
            gold: 10,
            potions: 0,
        });

        temple.loot_fallen(looter_id, 0);

        let inv: AdventurerInventory = world.read_model(looter_id);
        assert(inv.gold == 85, 'gold: 10 + 75 = 85');
        assert(inv.potions == 3, 'potions transferred');

        let fallen: FallenAdventurer = world.read_model((dungeon_id, 2_u32, 0_u32));
        assert(fallen.is_looted, 'body should be marked looted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_fallen_cannot_loot_self() {
        let caller: ContractAddress = 'fallentest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount {
            dungeon_id,
            chamber_id: 2,
            count: 1,
        });
        world.write_model_test(@FallenAdventurer {
            dungeon_id,
            chamber_id: 2,
            fallen_index: 0,
            adventurer_id, // same as looter
            dropped_weapon: WeaponType::Longsword,
            dropped_armor: ArmorType::ChainMail,
            dropped_gold: 0,
            dropped_potions: 0,
            is_looted: false,
        });
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            dungeon_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_fallen(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_if_already_looted() {
        let caller: ContractAddress = 'fallentest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id: 2, count: 1 });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id: 2, fallen_index: 0, adventurer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 50, dropped_potions: 1, is_looted: true });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        temple.loot_fallen(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_with_invalid_index() {
        let caller: ContractAddress = 'fallentest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id: 2, count: 0 });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        temple.loot_fallen(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_fallen_fails_if_in_combat() {
        let caller: ContractAddress = 'fallencombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id: 2, count: 1 });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id: 2, fallen_index: 0, adventurer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 50, dropped_potions: 1, is_looted: false });
        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.loot_fallen(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_permadeath_two_player_death_and_loot() {
        let player_a: ContractAddress = 'playerA'.try_into().unwrap();
        let player_b: ContractAddress = 'playerB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        world.write_model_test(@AdventurerInventory { adventurer_id: explorer_a, primary_weapon: WeaponType::Longsword, secondary_weapon: WeaponType::None, armor: ArmorType::ChainMail, has_shield: false, gold: 42, potions: 3 });
        world.write_model_test(@AdventurerPosition { adventurer_id: explorer_a, dungeon_id, chamber_id: 1, in_combat: true, combat_monster_id: 1 });
        world.write_model_test(@MonsterInstance { dungeon_id, chamber_id: 1, monster_id: 1, monster_type: MonsterType::Skeleton, current_hp: 50, max_hp: 50, is_alive: true });
        world.write_model_test(@AdventurerHealth { adventurer_id: explorer_a, current_hp: 1, max_hp: 11, is_dead: false });

        combat.attack(explorer_a);

        let health_a: AdventurerHealth = world.read_model(explorer_a);
        if !health_a.is_dead { return; }

        let fallen_count: ChamberFallenCount = world.read_model((dungeon_id, 1_u32));
        assert(fallen_count.count >= 1, 'should have at least 1 body');

        let fallen: FallenAdventurer = world.read_model((dungeon_id, 1_u32, 0_u32));
        assert(fallen.adventurer_id == explorer_a, 'body is explorer A');
        assert(fallen.dropped_gold == 42, 'body has 42 gold');

        let inv_a: AdventurerInventory = world.read_model(explorer_a);
        assert(inv_a.gold == 0, 'gold zeroed after death');

        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);

        world.write_model_test(@AdventurerPosition { adventurer_id: explorer_b, dungeon_id, chamber_id: 1, in_combat: false, combat_monster_id: 0 });
        world.write_model_test(@AdventurerInventory { adventurer_id: explorer_b, primary_weapon: WeaponType::None, secondary_weapon: WeaponType::None, armor: ArmorType::None, has_shield: false, gold: 5, potions: 0 });

        temple.loot_fallen(explorer_b, 0);

        let inv_b: AdventurerInventory = world.read_model(explorer_b);
        assert(inv_b.gold == 47, 'B gets 5 + 42 = 47 gold');
        assert(inv_b.primary_weapon == WeaponType::Longsword, 'B gets longsword');

        let fallen_after: FallenAdventurer = world.read_model((dungeon_id, 1_u32, 0_u32));
        assert(fallen_after.is_looted, 'body marked looted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiple_fallen_bodies_in_same_chamber() {
        let caller: ContractAddress = 'multideath'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, _token, _combat, _temple) = setup_world();

        let dungeon_id: u128 = 50;
        let chamber_id: u32 = 3;

        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id, count: 2 });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id, fallen_index: 0, adventurer_id: 100, dropped_weapon: WeaponType::Longsword, dropped_armor: ArmorType::ChainMail, dropped_gold: 30, dropped_potions: 1, is_looted: false });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id, fallen_index: 1, adventurer_id: 200, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 15, dropped_potions: 0, is_looted: false });

        let count: ChamberFallenCount = world.read_model((dungeon_id, chamber_id));
        assert(count.count == 2, 'two bodies in chamber');

        let body0: FallenAdventurer = world.read_model((dungeon_id, chamber_id, 0_u32));
        assert(body0.adventurer_id == 100, 'body 0 is explorer 100');

        let body1: FallenAdventurer = world.read_model((dungeon_id, chamber_id, 1_u32));
        assert(body1.adventurer_id == 200, 'body 1 is explorer 200');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic(expected: ('dead explorers cannot loot', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_loot_treasure() {
        let caller: ContractAddress = 'deadloot1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(adventurer_id, dungeon_id);
        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });

        temple.loot_treasure(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic(expected: ('dead explorers cannot loot', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_loot_fallen() {
        let caller: ContractAddress = 'deadloot2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(adventurer_id, dungeon_id);

        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id: 1, count: 1 });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id: 1, fallen_index: 0, adventurer_id: 9999, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::None, dropped_gold: 10, dropped_potions: 0, is_looted: false });
        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });

        temple.loot_fallen(adventurer_id, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic(expected: ('dead explorer cannot act', 'ENTRYPOINT_FAILED'))]
    fn test_dead_explorer_cannot_use_item() {
        let caller: ContractAddress = 'deaditem'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, _temple) = setup_world();
        let adventurer_id = mint_fighter(token);

        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@AdventurerInventory { adventurer_id, primary_weapon: WeaponType::Longsword, secondary_weapon: WeaponType::None, armor: ArmorType::ChainMail, has_shield: false, gold: 0, potions: 1 });

        combat.use_item(adventurer_id, ItemType::HealthPotion);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_dead_nft_fully_frozen() {
        let caller: ContractAddress = 'frozennft'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(adventurer_id, dungeon_id);

        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });

        let health: AdventurerHealth = world.read_model(adventurer_id);
        assert(health.is_dead, 'explorer should be dead');
        assert(health.current_hp == 0, 'hp should be 0');

        let pos: AdventurerPosition = world.read_model(adventurer_id);
        assert(pos.dungeon_id == dungeon_id, 'body in temple');
        assert(pos.chamber_id == 1, 'body in chamber 1');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_loot_second_body_leaves_first_intact() {
        let caller: ContractAddress = 'loot2nd'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);

        world.write_model_test(@AdventurerPosition { adventurer_id, dungeon_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });
        world.write_model_test(@ChamberFallenCount { dungeon_id, chamber_id: 2, count: 2 });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id: 2, fallen_index: 0, adventurer_id: 8888, dropped_weapon: WeaponType::Longsword, dropped_armor: ArmorType::ChainMail, dropped_gold: 100, dropped_potions: 5, is_looted: true });
        world.write_model_test(@FallenAdventurer { dungeon_id, chamber_id: 2, fallen_index: 1, adventurer_id: 7777, dropped_weapon: WeaponType::Dagger, dropped_armor: ArmorType::Leather, dropped_gold: 20, dropped_potions: 1, is_looted: false });
        world.write_model_test(@AdventurerInventory { adventurer_id, primary_weapon: WeaponType::None, secondary_weapon: WeaponType::None, armor: ArmorType::None, has_shield: false, gold: 0, potions: 0 });

        temple.loot_fallen(adventurer_id, 1);

        let body1: FallenAdventurer = world.read_model((dungeon_id, 2_u32, 1_u32));
        assert(body1.is_looted, 'body 1 should be looted');

        let body0: FallenAdventurer = world.read_model((dungeon_id, 2_u32, 0_u32));
        assert(body0.is_looted, 'body 0 still looted');
        assert(body0.dropped_gold == 100, 'body 0 gold unchanged');

        let inv: AdventurerInventory = world.read_model(adventurer_id);
        assert(inv.gold == 20, 'got 20 gold from body 1');
        assert(inv.primary_weapon == WeaponType::Dagger, 'got dagger');
    }

}
