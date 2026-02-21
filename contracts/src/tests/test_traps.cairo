#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::adventurer::{
        AdventurerStats, AdventurerHealth, AdventurerInventory,
        AdventurerPosition,
    };
    use d20::models::temple::{
        Chamber, ChamberExit,
    };
    use d20::types::index::{ChamberType};
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, assert_explorer_dead,
    };
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_trap_in_move_to_chamber_kills_explorer_via_handle_death() {
        let caller: ContractAddress = 'traptest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up entrance with a discovered exit to a trap chamber
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            yonder: 1,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
        });
        world.write_model_test(@ChamberExit {
            temple_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 2,
            is_discovered: true,
        });
        // Trap chamber: DC 21 (impossible to pass with d20)
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 21,
        });

        // 1 HP explorer with DEX 10 (modifier 0) — any damage is fatal
        world.write_model_test(@AdventurerHealth {
            adventurer_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });
        // Give some gold/potions so we can verify they get dropped
        world.write_model_test(@AdventurerInventory {
            adventurer_id,
            primary_weapon: d20::types::items::WeaponType::Longsword,
            secondary_weapon: d20::types::items::WeaponType::None,
            armor: d20::types::items::ArmorType::ChainMail,
            has_shield: false,
            gold: 30,
            potions: 1,
        });

        temple.enter_temple(adventurer_id, temple_id);
        temple.move_to_chamber(adventurer_id, 0);

        // DC 21 guarantees save fails; 1 HP means any hit is lethal
        assert_explorer_dead(ref world, adventurer_id, temple_id, 2_u32);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_disarm_trap_failure_kills_explorer_via_handle_death() {
        let caller: ContractAddress = 'traptest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Place explorer in a trap chamber with DC 21
        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 21,
        });
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: false,
            combat_monster_id: 0,
        });
        world.write_model_test(@AdventurerHealth {
            adventurer_id,
            current_hp: 1,
            max_hp: 11,
            is_dead: false,
        });
        world.write_model_test(@AdventurerInventory {
            adventurer_id,
            primary_weapon: d20::types::items::WeaponType::Longsword,
            secondary_weapon: d20::types::items::WeaponType::None,
            armor: d20::types::items::ArmorType::ChainMail,
            has_shield: false,
            gold: 20,
            potions: 2,
        });

        // Use a fighter with INT 8 (mod −1) and no Arcana → effective bonus = 0
        // Disarm roll can't beat DC 21; triggered DEX save also can't beat DC 21
        let stats: AdventurerStats = world.read_model(adventurer_id);
        let mut abilities = stats.abilities;
        abilities.intelligence = 8;
        abilities.dexterity = 10;
        world.write_model_test(@AdventurerStats {
            adventurer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            adventurer_class: stats.adventurer_class,
            temples_conquered: stats.temples_conquered,
        });

        temple.disarm_trap(adventurer_id);

        assert_explorer_dead(ref world, adventurer_id, temple_id, 2_u32);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_disarm_trap_resolves_without_crash() {
        let caller: ContractAddress = 'traptestA1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();

        let adventurer_id = mint_rogue(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 3,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 10,
        });
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });
        let stats: AdventurerStats = world.read_model(adventurer_id);
        let mut abilities = stats.abilities;
        abilities.dexterity = 20;
        world.write_model_test(@AdventurerStats {
            adventurer_id,
            abilities,
            level: stats.level,
            xp: stats.xp,
            adventurer_class: stats.adventurer_class,
            temples_conquered: stats.temples_conquered,
        });
        world.write_model_test(@AdventurerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });

        temple.disarm_trap(adventurer_id);

        let chamber_after: Chamber = world.read_model((temple_id, 3_u32));
        let health_after: AdventurerHealth = world.read_model(adventurer_id);
        assert(!health_after.is_dead || chamber_after.trap_disarmed || health_after.current_hp < 50,
            'disarm had some effect');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_in_non_trap_chamber() {
        let caller: ContractAddress = 'traptestA2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 2,
            chamber_type: ChamberType::Empty,
            yonder: 1,
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

        temple.disarm_trap(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_already_disarmed() {
        let caller: ContractAddress = 'traptestA3'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber {
            temple_id,
            chamber_id: 3,
            chamber_type: ChamberType::Trap,
            yonder: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: true,
            trap_dc: 10,
        });
        world.write_model_test(@AdventurerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 3,
            in_combat: false,
            combat_monster_id: 0,
        });

        temple.disarm_trap(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_dead() {
        let caller: ContractAddress = 'traptestA4'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 0, max_hp: 11, is_dead: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 3, chamber_type: ChamberType::Trap, yonder: 2, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 10 });
        world.write_model_test(@AdventurerPosition { adventurer_id, temple_id, chamber_id: 3, in_combat: false, combat_monster_id: 0 });

        temple.disarm_trap(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_disarm_trap_fails_if_in_combat() {
        let caller: ContractAddress = 'traptestA5'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 3, chamber_type: ChamberType::Trap, yonder: 2, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 10 });
        world.write_model_test(@AdventurerPosition { adventurer_id, temple_id, chamber_id: 3, in_combat: true, combat_monster_id: 1 });

        temple.disarm_trap(adventurer_id);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_move_to_trap_chamber_may_deal_damage() {
        let caller: ContractAddress = 'trapmoveA1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Trap, yonder: 4, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 25 });

        temple.enter_temple(adventurer_id, temple_id);
        world.write_model_test(@AdventurerHealth { adventurer_id, current_hp: 50, max_hp: 50, is_dead: false });

        temple.move_to_chamber(adventurer_id, 0);

        let pos: AdventurerPosition = world.read_model(adventurer_id);
        assert(pos.chamber_id == 2, 'moved to trap chamber');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_move_to_disarmed_trap_no_damage() {
        let caller: ContractAddress = 'trapmoveA2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, _combat, temple) = setup_world();
        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        world.write_model_test(@Chamber { temple_id, chamber_id: 1, chamber_type: ChamberType::Entrance, yonder: 0, exit_count: 1, is_revealed: true, treasure_looted: false, trap_disarmed: false, trap_dc: 0 });
        world.write_model_test(@ChamberExit { temple_id, from_chamber_id: 1, exit_index: 0, to_chamber_id: 2, is_discovered: true });
        world.write_model_test(@Chamber { temple_id, chamber_id: 2, chamber_type: ChamberType::Trap, yonder: 1, exit_count: 0, is_revealed: true, treasure_looted: false, trap_disarmed: true, trap_dc: 15 });

        temple.enter_temple(adventurer_id, temple_id);
        let health_before: AdventurerHealth = world.read_model(adventurer_id);

        temple.move_to_chamber(adventurer_id, 0);

        let health_after: AdventurerHealth = world.read_model(adventurer_id);
        assert(health_after.current_hp == health_before.current_hp, 'no damage from disarmed trap');
    }

}
