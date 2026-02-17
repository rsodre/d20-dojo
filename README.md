# ai-thon
Cartridge AI Hackathon Project

## Steps

1. [x] Install [Dojo skills](https://book.dojoengine.org/overview#ai-assisted-development): `npx skills add dojoengine/book --yes`
2. [x] Create [`.tool-versions`](.tool-versions)
3. [x] Initialize Dojo project: `sozo init contracts` in `packages/`
4. [x] Review and fix SPEC.md: Dojo model syntax, architecture, game logic inconsistencies
5. [x] Apply user feedback: OZ + cairo-nft-combo NFTs, namespace `d2_0_1`, signed integers for D20, extract TASKS.md
6. [x] Task 1.1: Replace starter code — updated namespace to `d20_0_1`, renamed package to `d20`, updated world name/seed, set up new module structure (types, events, models, systems, utils), removed starter models/systems/tests
7. [x] Tasks 1.2-1.4: Implement all enums (12 types in `types.cairo`), explorer models (6 models in `models/explorer.cairo`), and temple/chamber models (7 models in `models/temple.cairo`)
8. [x] Task 1.5: Implement D20 utility module (`utils/d20.cairo`) with VRF dice rolling (`roll_d20`, `roll_dice`), `ability_modifier`, `proficiency_bonus`, `calculate_ac` — plus local VRF interface (`utils/vrf.cairo`) and 30 unit tests (all passing)
9. [x] Tasks 1.6-1.8: Monster stat lookup (7 monsters with full SRD stats), all 6 Dojo events, and complete D20 math unit tests (41 tests passing — all 18 ability scores, proficiency by level, AC combos, monster stats)
10. [x] Tasks 1.9 & 2.1: Confirm `dojo_dev.toml` writer permissions for all 3 contracts; implement `explorer_token` contract with `mint_explorer` (standard array validation, class-based stat/equipment/skill init, sequential ID via `world.uuid()`, all 6 explorer models written, `ExplorerMinted` event emitted) and `rest` (HP restore, spell slot reset, class resource reset)
11. [x] Tasks 2.2 & 2.3: Class-specific skill choice validation (Fighter: 1 from Perception/Acrobatics; Rogue: 2 from Perception/Persuasion/Athletics/Arcana + 2 expertise picks with no duplicates; Wizard: 1 from Perception/Persuasion); `rest` was already implemented in task 2.1
12. [x] Task 2.4: Implement `combat_system` contract — `attack` function with d20 attack roll vs monster AC (nat-1 auto-miss, nat-20 crit with double damage dice), weapon damage roll with ability modifier, HP deduction on `MonsterInstance`, monster death clears `in_combat` flag on `ExplorerPosition`, `CombatResult` event emitted; stub entry points for all other combat actions (tasks 2.5-2.10)
13. [x] Tasks 2.5, 2.6 & 2.7: Monster counter-attack (multiattack support, attack roll vs explorer AC, damage + bonus, explorer death detection); Fighter: Extra Attack at level 5, Champion crit on 19-20 at level 3, `second_wind` heal 1d10+level (once per rest); Rogue: Sneak Attack bonus dice (1d6/2d6/3d6 by level, doubled on crit) added to `attack`, `cunning_action` disengage (level 2+, no counter-attack)
14. [x] Task 2.8: Wizard `cast_spell` — slot consumption per spell level; cantrips: Fire Bolt (attack roll + 1d10, crit 2d10), Mage Hand/Light (utility); 1st: Magic Missile (3×1d4+1 auto-hit), Shield (+5 AC), Sleep (5d8 HP threshold); 2nd: Scorching Ray (3 rays × attack + 2d6), Misty Step (disengage); 3rd: Fireball (8d6, DEX save DC 8+INT+prof for half). `use_item`: HealthPotion heals 2d4+2. Monster counter-attacks after all spells except kills and Misty Step.
