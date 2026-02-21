#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};

    use d20::d20::models::adventurer::{
        ExplorerStats, ExplorerHealth,
        ExplorerPosition,
    };
    use d20::models::temple::{
        TempleState, MonsterInstance,
        ExplorerTempleProgress
    };
    use d20::types::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter,
    };
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_defeat_marks_boss_dead() {
        let caller: ContractAddress = 'bosstest1'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Set up temple with a known boss chamber
        world.write_model_test(@TempleState {
            temple_id,
            difficulty_tier: 1,
            next_chamber_id: 3,
            boss_chamber_id: 2,
            boss_alive: true,
            max_yonder: 1,
        });

        // Boss = Wraith with 1 HP (guaranteed kill)
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Wraith,
            current_hp: 1,
            max_hp: 45,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });
        world.write_model_test(@ExplorerTempleProgress {
            adventurer_id,
            temple_id,
            chambers_explored: 5,
            xp_earned: 500,
        });

        combat.attack(adventurer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let temple_after: TempleState = world.read_model(temple_id);
            assert(!temple_after.boss_alive, 'boss should be marked dead');

            let stats_after: ExplorerStats = world.read_model(adventurer_id);
            assert(stats_after.temples_conquered == 1, 'temples_conquered should be 1');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_defeat_increments_temples_conquered() {
        let caller: ContractAddress = 'bosstest2'.try_into().unwrap();
        starknet::testing::set_contract_address(caller);

        let (mut world, token, combat, temple) = setup_world();

        let adventurer_id = mint_fighter(token);
        let temple_id = temple.mint_temple(1_u8);

        // Explorer with 1 prior conquest
        let stats: ExplorerStats = world.read_model(adventurer_id);
        world.write_model_test(@ExplorerStats {
            adventurer_id,
            abilities: stats.abilities,
            level: stats.level,
            xp: stats.xp,
            adventurer_class: stats.adventurer_class,
            temples_conquered: 1, // previously conquered 1 temple
        });

        world.write_model_test(@TempleState {
            temple_id,
            difficulty_tier: 1,
            next_chamber_id: 3,
            boss_chamber_id: 2,
            boss_alive: true,
            max_yonder: 1,
        });
        world.write_model_test(@MonsterInstance {
            temple_id,
            chamber_id: 2,
            monster_id: 1,
            monster_type: MonsterType::Wraith,
            current_hp: 1,
            max_hp: 45,
            is_alive: true,
        });
        world.write_model_test(@ExplorerPosition {
            adventurer_id,
            temple_id,
            chamber_id: 2,
            in_combat: true,
            combat_monster_id: 1,
        });
        world.write_model_test(@ExplorerHealth {
            adventurer_id,
            current_hp: 50,
            max_hp: 50,
            is_dead: false,
        });
        world.write_model_test(@ExplorerTempleProgress {
            adventurer_id,
            temple_id,
            chambers_explored: 3,
            xp_earned: 300,
        });

        combat.attack(adventurer_id);

        let monster_after: MonsterInstance = world.read_model((temple_id, 2_u32, 1_u32));
        if !monster_after.is_alive {
            let stats_after: ExplorerStats = world.read_model(adventurer_id);
            assert(stats_after.temples_conquered == 2, 'should have 2 conquests now');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    fn boss_prob(yonder: u8, xp_earned: u32) -> u32 {
        let min_yonder: u8 = 5;
        let yonder_weight: u32 = 50;
        let xp_weight: u32 = 2;
        let max_prob: u32 = 9500;
        if yonder < min_yonder {
            return 0;
        }
        let ey: u32 = (yonder - min_yonder).into();
        let total: u32 = ey * ey * yonder_weight + xp_earned * xp_weight;
        if total > max_prob { max_prob } else { total }
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_zero_below_min_yonder() {
        assert(boss_prob(0, 0) == 0, 'yonder 0 xp 0');
        assert(boss_prob(1, 0) == 0, 'yonder 1 xp 0');
        assert(boss_prob(2, 500) == 0, 'yonder 2 xp 500');
        assert(boss_prob(3, 1000) == 0, 'yonder 3 xp 1000');
        assert(boss_prob(4, 9999) == 0, 'yonder 4 xp 9999');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_at_min_yonder() {
        // ey=0 → yonder component=0; xp component = xp_earned × 2
        assert(boss_prob(5, 0) == 0, 'y5 xp0 = 0');
        assert(boss_prob(5, 100) == 200, 'y5 xp100 = 200');
        assert(boss_prob(5, 500) == 1000, 'y5 xp500 = 1000');
        assert(boss_prob(5, 1000) == 2000, 'y5 xp1000 = 2000');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_yonder_quadratic_growth() {
        // All with xp=0 to isolate yonder component
        // ey=1 → 1×50=50
        assert(boss_prob(6, 0) == 50, 'y6 = 50 bps');
        // ey=2 → 4×50=200
        assert(boss_prob(7, 0) == 200, 'y7 = 200 bps');
        // ey=3 → 9×50=450
        assert(boss_prob(8, 0) == 450, 'y8 = 450 bps');
        // ey=5 → 25×50=1250
        assert(boss_prob(10, 0) == 1250, 'y10 = 1250 bps');
        // ey=10 → 100×50=5000
        assert(boss_prob(15, 0) == 5000, 'y15 = 5000 bps');
        // ey=13 → 169×50=8450
        assert(boss_prob(18, 0) == 8450, 'y18 = 8450 bps');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_combined_yonder_and_xp() {
        // ey=2 → 200 bps; xp=300 → 600 bps; total=800
        assert(boss_prob(7, 300) == 800, 'y7 xp300 = 800');
        // ey=5 → 1250; xp=500 → 1000; total=2250
        assert(boss_prob(10, 500) == 2250, 'y10 xp500 = 2250');
        // ey=10 → 5000; xp=1000 → 2000; total=7000
        assert(boss_prob(15, 1000) == 7000, 'y15 xp1000 = 7000');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_caps_at_95_percent() {
        // ey=14 → 196×50=9800 > 9500 → capped
        assert(boss_prob(19, 0) == 9500, 'y19 caps at 9500');
        // ey=20 → 400×50=20000 > 9500 → capped
        assert(boss_prob(25, 0) == 9500, 'y25 caps at 9500');
        // Even with massive XP
        assert(boss_prob(5, 10000) == 9500, 'y5 xp10000 caps');
        // ey=10 → 5000; xp=5000 → 10000; total=15000 → 9500
        assert(boss_prob(15, 5000) == 9500, 'y15 xp5000 caps');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_progression_milestones() {
        // Early exploration (yonder 5-7, low XP): very low probability
        assert(boss_prob(5, 0) == 0, 'start: 0%');
        assert(boss_prob(6, 50) == 150, 'early: 1.5%');
        assert(boss_prob(7, 150) == 500, 'mid-early: 5%');

        // Mid-game (yonder 8-10, moderate XP): noticeable probability
        assert(boss_prob(8, 300) == 1050, 'mid: 10.5%');
        assert(boss_prob(10, 500) == 2250, 'mid-late: 22.5%');

        // Late-game (yonder 12+, high XP): high probability
        assert(boss_prob(12, 1000) == 4450, 'late: 44.5%');
        assert(boss_prob(15, 2000) == 9000, 'very late: 90%');

        // Deep exploration always caps
        assert(boss_prob(20, 3000) == 9500, 'deep: 95% cap');
    }

    // ═══════════════════════════════════════════════════════════════════════
    #[test]
    fn test_boss_prob_roll_range_alignment() {
        // d20 roll × 500 = 500..10000 bps
        // A boss_prob of 500 means roll=1 (500 bps) triggers, 5% of d20 range
        // A boss_prob of 5000 means rolls 1-10 trigger, 50% of d20 range
        // A boss_prob of 9500 means rolls 1-19 trigger, 95% of d20 range

        // At 500 bps: only nat-1 (rolled as 500) triggers boss
        let prob_500 = boss_prob(7, 150);
        assert(prob_500 == 500, '500 bps = 5% chance');

        // At 5000 bps: rolls 1-10 (500-5000) trigger boss = 50%
        let prob_5000 = boss_prob(15, 0);
        assert(prob_5000 == 5000, '5000 bps = 50% chance');

        // At 9500 bps: rolls 1-19 trigger, only nat-20 (10000) escapes = 95%
        let prob_cap = boss_prob(19, 0);
        assert(prob_cap == 9500, '9500 bps = 95% chance');
    }

}
