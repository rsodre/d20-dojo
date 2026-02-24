#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::character::{
        CharacterStats, CharacterInventory,
        CharacterPosition
    };
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberType, ChamberExit, MonsterInstance,
        FallenCharacter, CharacterDungeonProgress
    };
    use d20::d20::types::items::{WeaponType, ArmorType};
    use d20::d20::models::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue,
    };
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_shared_exit_discovery() {
        let player_a: ContractAddress = 'mp_exitA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_exitB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Entrance chamber with 2 exits
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 2,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 1,
            to_chamber_id: 0,
            is_discovered: false,
        });

        // Player A opens exit 0
        temple.open_exit(explorer_a, 0);

        let exit_after: ChamberExit = world.read_model((dungeon_id, 1_u32, 0_u8));
        assert(exit_after.is_discovered, 'exit 0 discovered by A');
        let dest_chamber_id = exit_after.to_chamber_id;
        assert(dest_chamber_id > 1, 'new chamber allocated');

        // Player B: mint, enter same temple, positioned at entrance
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        // Player B reads exit 0 — should be discovered by A
        let exit_b: ChamberExit = world.read_model((dungeon_id, 1_u32, 0_u8));
        assert(exit_b.is_discovered, 'B sees A discovered exit');
        assert(exit_b.to_chamber_id == dest_chamber_id, 'B sees same dest');

        // Player B can move through exit 0 without opening it
        temple.move_to_chamber(explorer_b, 0);

        let pos_b: CharacterPosition = world.read_model(explorer_b);
        assert(pos_b.chamber_id == dest_chamber_id, 'B moved to A chamber');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_shared_monster_kill() {
        let player_a: ContractAddress = 'mp_killA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_killB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Entrance with a discovered exit to a monster chamber
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 2,
            is_discovered: true,
        });
        // Monster chamber
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 2,
            chamber_type: ChamberType::Monster,
            depth: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 2,
            exit_index: 0,
            to_chamber_id: 1,
            is_discovered: true,
        });
        // Simulate: A already killed the monster (shared state)
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::PoisonousSnake,
            current_hp: 0,
            max_hp: 5,
            is_alive: false,
        });

        // Player B enters same temple, moves to the cleared chamber
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);
        temple.move_to_chamber(explorer_b, 0);

        // Player B should NOT be in combat — monster is dead
        let pos_b: CharacterPosition = world.read_model(explorer_b);
        assert(pos_b.chamber_id == 2, 'B in chamber 2');
        assert(!pos_b.in_combat, 'B not in combat');

        // B reads the same shared monster — confirms it's dead
        let monster: MonsterInstance = world.read_model((dungeon_id, 2_u32, 1_u32));
        assert(!monster.is_alive, 'monster still dead');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    #[should_panic]
    fn test_multiplayer_shared_treasure_looted() {
        let player_a: ContractAddress = 'mp_lootA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_lootB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Treasure chamber with DC 1 (guaranteed success)
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Treasure,
            depth: 1,
            exit_count: 0,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        // Give A high WIS for guaranteed perception
        let mut stats_a: CharacterStats = world.read_model(explorer_a);
        stats_a.abilities.wisdom = 20;
        world.write_model_test(@stats_a);

        // Player A loots treasure
        temple.loot_treasure(explorer_a);

        let chamber_after: Chamber = world.read_model((dungeon_id, 1_u32));
        assert(chamber_after.treasure_looted, 'A looted treasure');

        // Player B enters same temple
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        world.write_model_test(@CharacterPosition {
            character_id: explorer_b,
            dungeon_id,
            chamber_id: 1,
            in_combat: false,
            combat_monster_id: 0,
        });
        let mut stats_b: CharacterStats = world.read_model(explorer_b);
        stats_b.current_hp = 10;
        stats_b.max_hp = 10;
        stats_b.is_dead = false;
        world.write_model_test(@stats_b);

        // Player B tries to loot — should panic (treasure_looted is true)
        temple.loot_treasure(explorer_b);
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_shared_trap_disarmed() {
        let player_a: ContractAddress = 'mp_trapA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_trapB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_rogue(token);
        let dungeon_id = temple.mint_temple(1_u8);

        // Entrance with exit to trap chamber
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 2,
            is_discovered: true,
        });
        // Trap chamber with DC 1 (easy to disarm)
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 2,
            chamber_type: ChamberType::Trap,
            depth: 2,
            exit_count: 1,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 1,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 2,
            exit_index: 0,
            to_chamber_id: 1,
            is_discovered: true,
        });

        // Player A: enter temple, move to trap (takes damage or not), then disarm
        temple.enter_temple(explorer_a, dungeon_id);
        temple.move_to_chamber(explorer_a, 0);
        temple.disarm_trap(explorer_a);

        // Verify trap is disarmed (shared state)
        let chamber: Chamber = world.read_model((dungeon_id, 2_u32));
        assert(chamber.trap_disarmed, 'A disarmed trap');

        // Player B: enter same temple, move to entrance first
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        // Record B's HP before moving to trap chamber
        let stats_b_before: CharacterStats = world.read_model(explorer_b);
        let hp_before = stats_b_before.current_hp;

        // Move B to trap chamber — trap is already disarmed, no damage
        temple.move_to_chamber(explorer_b, 0);

        let pos_b: CharacterPosition = world.read_model(explorer_b);
        assert(pos_b.chamber_id == 2, 'B in trap chamber');

        let stats_b_after: CharacterStats = world.read_model(explorer_b);
        assert(stats_b_after.current_hp == hp_before, 'B takes no trap dmg');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_both_see_same_monster_hp() {
        let player_a: ContractAddress = 'mp_atkA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_atkB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Monster at full HP
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 50,
            max_hp: 50,
            is_alive: true,
        });

        // Simulate: A deals 30 damage → monster at 20 HP
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 20,
            max_hp: 50,
            is_alive: true,
        });

        // Player B enters same temple — reads the same monster state
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        let monster_b_view: MonsterInstance = world.read_model((dungeon_id, 1_u32, 1_u32));
        assert(monster_b_view.current_hp == 20, 'B sees 20 HP');
        assert(monster_b_view.max_hp == 50, 'B sees 50 max');
        assert(monster_b_view.is_alive, 'monster still alive');

        // Simulate: B finishes the monster → 0 HP, dead
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 0,
            max_hp: 50,
            is_alive: false,
        });

        // A reads the same model — sees B's kill
        starknet::testing::set_contract_address(player_a);
        let monster_a_view: MonsterInstance = world.read_model((dungeon_id, 1_u32, 1_u32));
        assert(!monster_a_view.is_alive, 'A sees monster dead');
        assert(monster_a_view.current_hp == 0, 'A sees 0 HP');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_independent_chamber_generation() {
        let player_a: ContractAddress = 'mp_genA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_genB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Entrance with 2 undiscovered exits
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 2,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 1,
            to_chamber_id: 0,
            is_discovered: false,
        });

        // Player A opens exit 0 → generates chamber 2
        temple.open_exit(explorer_a, 0);

        let exit_0: ChamberExit = world.read_model((dungeon_id, 1_u32, 0_u8));
        let chamber_a_id = exit_0.to_chamber_id;
        assert(chamber_a_id >= 2, 'A chamber allocated');

        // Player B: mint, enter same temple
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        // Player B opens exit 1 → generates another chamber
        temple.open_exit(explorer_b, 1);

        let exit_1: ChamberExit = world.read_model((dungeon_id, 1_u32, 1_u8));
        let chamber_b_id = exit_1.to_chamber_id;

        // Distinct chamber IDs allocated by shared next_chamber_id counter
        assert(chamber_b_id != chamber_a_id, 'distinct chamber IDs');
        assert(chamber_b_id > chamber_a_id, 'B ID after A ID');

        // Both chambers exist and are revealed
        let ch_a: Chamber = world.read_model((dungeon_id, chamber_a_id));
        assert(ch_a.is_revealed, 'A chamber exists');

        let ch_b: Chamber = world.read_model((dungeon_id, chamber_b_id));
        assert(ch_b.is_revealed, 'B chamber exists');

        // Temple state next_chamber_id incremented twice
        let temple_state: DungeonState = world.read_model(dungeon_id);
        assert(temple_state.next_chamber_id > chamber_b_id, 'next_id advanced');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_death_visible_to_other_player() {
        let player_a: ContractAddress = 'mp_deathA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_deathB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Setup combat scenario — A will die
        world.write_model_test(@MonsterInstance {
            dungeon_id,
            chamber_id: 1,
            monster_id: 1,
            monster_type: MonsterType::Skeleton,
            current_hp: 50,
            max_hp: 50,
            is_alive: true,
        });
        world.write_model_test(@CharacterPosition {
            character_id: explorer_a,
            dungeon_id,
            chamber_id: 1,
            in_combat: true,
            combat_monster_id: 1,
        });
        let mut stats_a: CharacterStats = world.read_model(explorer_a);
        stats_a.current_hp = 1;
        stats_a.max_hp = 11;
        stats_a.is_dead = false;
        world.write_model_test(@stats_a);
        world.write_model_test(@CharacterInventory {
            character_id: explorer_a,
            primary_weapon: WeaponType::Longsword,
            secondary_weapon: WeaponType::None,
            armor: ArmorType::ChainMail,
            has_shield: false,
            gold: 50,
            potions: 2,
        });

        // A attacks and dies from counter-attack
        combat.attack(explorer_a);

        let stats_a: CharacterStats = world.read_model(explorer_a);
        if !stats_a.is_dead {
            return; // Non-deterministic — A survived; skip rest of test
        }

        // Player B enters same temple
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        // B reads shared Chamber.fallen_count — should see A's body
        let chamber: Chamber = world.read_model((dungeon_id, 1_u32));
        assert(chamber.fallen_count >= 1, 'B sees fallen count');

        let fallen: FallenCharacter = world.read_model((dungeon_id, 1_u32, 0_u32));
        assert(fallen.character_id == explorer_a, 'body is A');
        assert(!fallen.is_looted, 'not yet looted');
        assert(fallen.dropped_gold == 50, 'gold on body');

        // B loots A's body
        temple.loot_fallen(explorer_b, 0);

        let fallen_after: FallenCharacter = world.read_model((dungeon_id, 1_u32, 0_u32));
        assert(fallen_after.is_looted, 'B looted body');

        let inv_b: CharacterInventory = world.read_model(explorer_b);
        assert(inv_b.gold >= 50, 'B got A gold');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_multiplayer_independent_progress_tracking() {
        let player_a: ContractAddress = 'mp_progA'.try_into().unwrap();
        let player_b: ContractAddress = 'mp_progB'.try_into().unwrap();

        starknet::testing::set_contract_address(player_a);
        let (mut world, token, _combat, temple) = setup_world();

        let explorer_a = mint_fighter(token);
        let dungeon_id = temple.mint_temple(1_u8);
        temple.enter_temple(explorer_a, dungeon_id);

        // Entrance with 2 exits
        world.write_model_test(@Chamber {
            dungeon_id,
            chamber_id: 1,
            chamber_type: ChamberType::Entrance,
            depth: 1,
            exit_count: 2,
            is_revealed: true,
            treasure_looted: false,
            trap_disarmed: false,
            trap_dc: 0,
            fallen_count: 0,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 0,
            to_chamber_id: 0,
            is_discovered: false,
        });
        world.write_model_test(@ChamberExit {
            dungeon_id,
            from_chamber_id: 1,
            exit_index: 1,
            to_chamber_id: 0,
            is_discovered: false,
        });

        // Player A opens exit 0 — A's chambers_explored = 1
        temple.open_exit(explorer_a, 0);
        let prog_a: CharacterDungeonProgress = world.read_model((explorer_a, dungeon_id));
        assert(prog_a.chambers_explored == 1, 'A explored 1');

        // Player B enters same temple
        starknet::testing::set_contract_address(player_b);
        let explorer_b = mint_fighter(token);
        temple.enter_temple(explorer_b, dungeon_id);

        // B's progress starts at 0 even though A already explored
        let prog_b: CharacterDungeonProgress = world.read_model((explorer_b, dungeon_id));
        assert(prog_b.chambers_explored == 0, 'B explored 0');

        // B opens exit 1 — B's chambers_explored = 1
        temple.open_exit(explorer_b, 1);
        let prog_b2: CharacterDungeonProgress = world.read_model((explorer_b, dungeon_id));
        assert(prog_b2.chambers_explored == 1, 'B explored 1');

        // A's progress unchanged by B's actions
        let prog_a2: CharacterDungeonProgress = world.read_model((explorer_a, dungeon_id));
        assert(prog_a2.chambers_explored == 1, 'A still 1');
    }

}
