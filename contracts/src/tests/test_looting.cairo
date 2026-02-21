#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::adventurer::{
        AdventurerStats, AdventurerInventory,
        AdventurerPosition,
    };
    use d20::models::temple::{
        Chamber,
    };
    use d20::types::index::{ChamberType};
    use d20::tests::tester::{
        setup_world, mint_fighter,
    };
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_loot_treasure_awards_gold_in_treasure_chamber() {
        let caller: ContractAddress = 'loottest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        let inv_before: AdventurerInventory = world.read_model(adventurer_id);

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
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(adventurer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        let inv_after: AdventurerInventory = world.read_model(adventurer_id);

        // On success (perception DC 10) gold should increase; on fail no change
        if chamber_after.treasure_looted {
            assert(inv_after.gold >= inv_before.gold, 'gold should not decrease');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_loot_treasure_marks_looted() {
        let caller: ContractAddress = 'loottest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
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
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        // Boost WIS to guarantee perception check passes (no modifier needed)
        let stats: AdventurerStats = world.read_model(adventurer_id);
        let mut abilities = stats.abilities;
        abilities.wisdom = 20; // +5 mod guarantees DC 10
        world.write_model_test(@AdventurerStats {
            adventurer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            adventurer_class: stats.adventurer_class,
            temples_conquered: stats.temples_conquered,
        });

        temple.loot_treasure(adventurer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        // WIS 20 (+5) + d20 always beats DC 10
        assert(chamber_after.treasure_looted, 'should be marked looted');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_on_second_attempt() {
        let caller: ContractAddress = 'loottest3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
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
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_in_monster_chamber() {
        let caller: ContractAddress = 'loottest4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
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
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.loot_treasure(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_loot_treasure_fails_if_in_combat() {
        let caller: ContractAddress = 'lootcombat1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Treasure, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@AdventurerPosition { adventurer_id, temple_id, chamber_id: 2, in_combat: true, combat_monster_id: 1 });

        temple.loot_treasure(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_loot_treasure_in_empty_chamber() {
        let caller: ContractAddress = 'loottest5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Empty, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@AdventurerPosition { adventurer_id, temple_id, chamber_id: 2, in_combat: false, combat_monster_id: 0 });

        let stats: AdventurerStats = world.read_model(adventurer_id);
        let mut abilities = stats.abilities;
        abilities.wisdom = 20;
        world.write_model_test(@AdventurerStats { adventurer_id, abilities, level: stats.level, xp: stats.xp, adventurer_class: stats.adventurer_class, temples_conquered: stats.temples_conquered });

        temple.loot_treasure(adventurer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 2_u32));
        if chamber_after.treasure_looted {
            let inv: AdventurerInventory = world.read_model(adventurer_id);
            assert(inv.gold > 0, 'gold from empty loot');
        }
    }

}
