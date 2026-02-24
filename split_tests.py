import os

with open("contracts/src/tests/test_integration.cairo", "r") as f:
    lines = f.read().splitlines()

groups = {
    "test_temple_lifecycle": [
        "test_mint_temple_creates_temple_state",
        "test_mint_temple_sequential_ids",
        "test_mint_temple_rejects_zero_difficulty",
        "test_enter_temple_places_explorer_at_entrance",
        "test_enter_temple_initializes_progress",
        "test_enter_temple_rejects_dead_explorer",
        "test_exit_temple_clears_position",
        "test_exit_temple_preserves_stats",
        "test_exit_temple_fails_not_in_temple",
        "test_exit_temple_fails_during_combat",
        "test_enter_temple_rejects_explorer_in_combat",
        "test_reenter_same_temple_preserves_progress"
    ],
    "test_exploration": [
        "test_open_exit_generates_new_chamber",
        "test_open_exit_increments_chambers_explored",
        "test_open_exit_creates_back_exit",
        "test_open_exit_fails_if_already_discovered",
        "test_open_exit_fails_with_invalid_index",
        "test_open_exit_fails_if_dead",
        "test_open_exit_fails_if_in_combat",
        "test_move_to_empty_chamber_no_combat",
        "test_move_to_undiscovered_exit_fails",
        "test_move_to_chamber_fails_if_dead",
        "test_move_to_chamber_fails_if_in_combat"
    ],
    "test_combat_and_progression": [
        "test_move_to_monster_chamber_triggers_combat",
        "test_attack_in_temple_records_position",
        "test_kill_monster_grants_xp",
        "test_kill_monster_updates_temple_progress",
        "test_level_up_increases_max_hp"
    ],
    "test_traps": [
        "test_trap_in_move_to_chamber_kills_explorer_via_handle_death",
        "test_disarm_trap_failure_kills_explorer_via_handle_death",
        "test_disarm_trap_resolves_without_crash",
        "test_disarm_trap_fails_in_non_trap_chamber",
        "test_disarm_trap_fails_if_already_disarmed",
        "test_disarm_trap_fails_if_dead",
        "test_disarm_trap_fails_if_in_combat",
        "test_move_to_trap_chamber_may_deal_damage",
        "test_move_to_disarmed_trap_no_damage"
    ],
    "test_looting": [
        "test_loot_treasure_awards_gold_in_treasure_chamber",
        "test_loot_treasure_marks_looted",
        "test_loot_treasure_fails_on_second_attempt",
        "test_loot_treasure_fails_in_monster_chamber",
        "test_loot_treasure_fails_if_in_combat",
        "test_loot_treasure_in_empty_chamber"
    ],
    "test_permadeath": [
        "test_loot_fallen_transfers_items",
        "test_loot_fallen_cannot_loot_self",
        "test_loot_fallen_fails_if_already_looted",
        "test_loot_fallen_fails_with_invalid_index",
        "test_loot_fallen_fails_if_in_combat",
        "test_permadeath_two_player_death_and_loot",
        "test_multiple_fallen_bodies_in_same_chamber",
        "test_dead_explorer_cannot_loot_treasure",
        "test_dead_explorer_cannot_loot_fallen",
        "test_dead_explorer_cannot_use_item",
        "test_dead_nft_fully_frozen",
        "test_loot_second_body_leaves_first_intact"
    ],
    "test_boss_mechanics": [
        "test_boss_defeat_marks_boss_dead",
        "test_boss_defeat_increments_dungeons_conquered",
        "test_boss_prob_zero_below_min_depth",
        "test_boss_prob_at_min_depth",
        "test_boss_prob_depth_quadratic_growth",
        "test_boss_prob_combined_depth_and_xp",
        "test_boss_prob_caps_at_95_percent",
        "test_boss_prob_progression_milestones",
        "test_boss_prob_roll_range_alignment"
    ],
    "test_cross_temple": [
        "test_cross_temple_stats_carry_over",
        "test_cross_temple_level_up_carries_over",
        "test_cross_temple_inventory_carries_over",
        "test_cross_temple_hp_not_auto_healed",
        "test_cross_temple_progress_is_per_temple",
        "test_cross_temple_class_resources_not_reset",
        "test_cross_temple_full_flow_with_rest"
    ],
    "test_multiplayer": [
        "test_multiplayer_shared_exit_discovery",
        "test_multiplayer_shared_monster_kill",
        "test_multiplayer_shared_treasure_looted",
        "test_multiplayer_shared_trap_disarmed",
        "test_multiplayer_both_see_same_monster_hp",
        "test_multiplayer_independent_chamber_generation",
        "test_multiplayer_death_visible_to_other_player",
        "test_multiplayer_independent_progress_tracking"
    ],
    "test_full_flows": [
        "test_full_flow_mint_enter_explore_fight_exit",
        "test_full_flow_rogue_enters_loots_exits",
        "test_full_flow_wizard_casts_spell_kills_monster"
    ]
}

tests_extracted = {}
i = 0
while i < len(lines):
    line = lines[i]
    if "#[test]" in line:
        # found the start of a test
        start_idx = i
        while i < len(lines) and not lines[i].strip().startswith("fn "):
            i += 1
        fn_line = lines[i]
        test_name = fn_line.split("fn ")[1].split("(")[0].strip()
        
        brace_count = 0
        in_body = False
        
        test_lines = lines[start_idx:i] # decorators
        
        while i < len(lines):
            test_lines.append(lines[i])
            brace_count += lines[i].count('{')
            brace_count -= lines[i].count('}')
            
            if "{" in lines[i]:
                in_body = True
                
            if in_body and brace_count == 0:
                break
            i += 1
            
        tests_extracted[test_name] = "\n".join(test_lines)
    i += 1

print(f"Extracted {len(tests_extracted)} tests.")

header_template = """#[cfg(test)]
mod tests {

    use starknet::{ContractAddress};
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait};

    use d20::d20::models::character::{
        CharacterStats, CharacterCombat, CharacterInventory,
        CharacterPosition, CharacterSkills
    };
    use d20::d20::models::dungeon::{
        DungeonState, Chamber, ChamberType, ChamberExit, MonsterInstance,
        FallenCharacter, CharacterDungeonProgress
    };
    use d20::d20::types::items::{WeaponType, ArmorType};
    use d20::d20::types::character_class::CharacterClass;
    use d20::d20::models::monster::MonsterType;
    use d20::tests::tester::{
        setup_world, mint_fighter, mint_rogue, mint_wizard, assert_explorer_dead,
    };
    use d20::systems::explorer_token::{IExplorerTokenDispatcherTrait};
    use d20::systems::combat_system::{ICombatSystemDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcherTrait};

"""

for group_name, test_names in groups.items():
    file_content = header_template
    for name in test_names:
        if name in tests_extracted:
            file_content += '    // ═══════════════════════════════════════════════════════════════════════\n'
            file_content += tests_extracted[name] + '\n\n'
        else:
            print(f"Warning: test {name} not found")
            
    file_content += "}\n"
    
    with open(f"contracts/src/tests/{group_name}.cairo", "w") as f:
        f.write(file_content)

print("Done grouping!")
