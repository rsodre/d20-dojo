# D20 On-Chain: Build Tasks

> Extracted from [SPEC.md](SPEC.md). Check off tasks as they are completed.

---

## Day 1: Foundation & Models

- [x] **1.1** Replace starter code: update namespace from `dojo_starter` to `d20_0_1` in `Scarb.toml` and `dojo_dev.toml`, update world name/seed, remove starter models/systems
- [x] **1.2** Define all enums in `src/types.cairo` with correct derives (`Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default`)
- [x] **1.3** Implement explorer models in `src/models/` (ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory, ExplorerPosition, ExplorerSkills) with `#[dojo::model]` and `#[derive(Copy, Drop, Serde)]`
- [x] **1.4** Implement temple/chamber models (TempleState, Chamber, MonsterInstance, ChamberExit, FallenExplorer, ChamberFallenCount, ExplorerTempleProgress)
- [x] **1.5** Implement D20 utility module (`src/utils/d20.cairo`): `roll_d20`, `roll_dice`, `ability_modifier`, `proficiency_bonus`, `calculate_ac`
- [x] **1.6** Implement monster stat lookup (`src/utils/monsters.cairo`): pure function returning stats for each MonsterType
- [x] **1.7** Define all events (`src/events.cairo`): ExplorerMinted, CombatResult, ExplorerDied, ChamberRevealed, LevelUp, BossDefeated
- [x] **1.8** Write unit tests for all D20 math (modifier calculation for all 18 scores, proficiency by level, roll bounds)
- [x] **1.9** Configure `dojo_dev.toml` writer permissions for all 3 contracts
- [x] **1.10** Set up Cartridge VRF integration (import VRF contract interface, configure provider)

## Day 2: Explorer & Combat Systems

- [x] **2.1** Implement `explorer_token` contract (`src/systems/explorer_token.cairo`): `mint_explorer` via cairo-nft-combo `_mint_next()`, validate standard array assignment, initialize all explorer models based on class, emit ExplorerMinted event
- [x] **2.2** Implement class-specific initialization: Fighter (Longsword primary, None secondary, Chain Mail, AC 16, Athletics + choice), Rogue (Dagger primary, Shortbow secondary, Leather, AC 11+DEX, Stealth/Acrobatics + 2 choices + expertise), Wizard (Staff primary, None secondary, no armor, AC 10+DEX, Arcana + choice, spell slots)
- [x] **2.3** Implement `rest` on `explorer_token`: restore `current_hp` to `max_hp`, reset spell slots to class/level values, reset `second_wind_used` and `action_surge_used`
- [x] **2.4** Implement `combat_system` contract (`src/systems/combat_system.cairo`): `attack` with attack rolls vs monster AC, damage rolls, HP deduction on MonsterInstance, emit CombatResult event
- [x] **2.5** Implement monster turn: after explorer action, monster attacks back (attack roll vs explorer AC, damage to explorer HP)
- [x] **2.6** Implement Fighter features (second_wind heal 1d10+level, Action Surge extra action, Champion crit on 19-20 at level 3, Extra Attack at level 5)
- [x] **2.7** Implement Rogue features (Sneak Attack bonus dice 1d6/2d6/3d6 by level, Expertise double proficiency, cunning_action disengage/hide, Uncanny Dodge halve damage at level 5)
- [x] **2.8** Implement Wizard spell casting: spell slot tracking per level, cantrip resolution (Fire Bolt attack roll + 1d10), leveled spell resolution (Magic Missile auto-hit 3x1d4+1, Shield +5 AC reaction, Sleep 5d8 HP, Scorching Ray 3x2d6, Misty Step, Fireball 8d6 DEX save using monster ability scores)
- [x] **2.9** Implement death (internal fn): set `is_dead`, create `FallenExplorer` with dropped loot, increment `ChamberFallenCount`, emit ExplorerDied event
- [x] **2.10** Implement `flee` mechanic: contested DEX check (explorer DEX vs monster DEX), on success move back to previous chamber
- [x] **2.11** Write unit tests for combat math, each class feature, and death flow using `spawn_test_world` and `write_model_test`

## Day 3: Temple & Exploration

- [x] **3.1** Implement `temple_token` contract (`src/systems/temple_token.cairo`)
- [ ] **3.2** Implement `mint_temple`: mint Temple NFT via cairo-nft-combo `_mint_next()`, create TempleState, create entrance chamber (chamber_id=1, yonder=0, type=Entrance), generate entrance exits from seed
- [x] **3.3** Implement `enter_temple`: validate explorer is alive and not in another temple, place at entrance chamber, initialize `ExplorerTempleProgress`
- [x] **3.4** Implement `exit_temple`: remove explorer from temple (set temple_id=0, chamber_id=0), retain stats/inventory/XP
- [x] **3.5** Implement `generate_chamber` (internal fn): derive chamber properties from temple seed + chamber position, calculate boss probability via Yonder Formula, determine chamber type / monster type / exit count / trap DC, create `MonsterInstance` model for monster chambers, emit ChamberRevealed event
- [x] **3.6** Implement `open_exit`: call `generate_chamber` for undiscovered exits, create bidirectional `ChamberExit` links, increment `chambers_explored` on `ExplorerTempleProgress`
- [x] **3.7** Implement `move_to_chamber`: validate exit is discovered, move explorer, trigger chamber events (monster encounter / trap)
- [x] **3.8** Implement `loot_treasure`: Perception skill check (d20 + WIS mod + proficiency), DC 10 Treasure / DC 12 Empty; success awards gold (1d6 × (yonder+1) × difficulty) + potion on roll ≥15; marks `treasure_looted=true`. Note: `search_chamber` was removed — traps fire immediately on `move_to_chamber` entry; loot pickup and treasure detection are merged into `loot_treasure`.
- [ ] **3.9** Implement trap mechanics: saving throw to avoid, damage on failure, `disarm_trap` skill check
- [ ] **3.10** Implement `loot_fallen`: pick up a fallen explorer's items, update inventory, mark `is_looted=true`
- [ ] **3.11** Implement XP gain and level-up: check thresholds, increase max HP (roll hit die + CON), update proficiency bonus, unlock class features, add spell slots for Wizard
- [ ] **3.12** Implement boss defeat: on boss kill, increment `temples_conquered`, mark `boss_alive = false`, emit BossDefeated event
- [ ] **3.13** Implement `calculate_boss_probability` with the Yonder Formula (quadratic yonder + XP component)
- [ ] **3.14** Write integration tests: full explorer-mints -> enters-temple -> opens-exits -> explores -> fights -> loots -> levels-up -> finds-boss flow

## Day 4: AI Agent & Client

- [ ] **4.1** Set up client project (TypeScript or Python)
- [ ] **4.2** Implement Torii GraphQL client: query explorer state (stats, HP, inventory, position, skills), chamber state (type, yonder, monster, exits, fallen explorers), temple state (seed, difficulty, boss status)
- [ ] **4.3** Implement Starknet transaction submission wrapper: build and sign transactions for each game action
- [ ] **4.4** Design the AI agent system prompt: D20 rules summary, available actions per context (exploring vs combat vs at entrance), narration style guidelines, examples of NL -> action mapping
- [ ] **4.5** Implement action mapping layer: LLM parses natural language -> structured action (enum + params), validate action is legal given current state
- [ ] **4.6** Implement narration layer: LLM reads transaction results + world state -> atmospheric text describing what happened
- [ ] **4.7** Implement game loop: read state -> show context -> player input -> AI maps action -> submit tx -> wait for result -> AI narrates -> repeat
- [ ] **4.8** Build simple chat UI (terminal CLI or minimal web interface with chat history)
- [ ] **4.9** Handle edge cases: invalid actions (AI retries with guidance), ambiguous input (AI asks for clarification), death (narrate death scene, prompt for new explorer)
- [ ] **4.10** Implement temple selection flow: list available temples, show difficulty tier, let player choose or mint new

## Day 5: Integration, Testing & Deploy

- [ ] **5.1** End-to-end playtest: mint explorer -> enter temple -> explore -> open exits -> fight -> loot -> level up -> find boss -> die or conquer
- [ ] **5.2** Test permadeath flow: verify fallen explorer body visible, loot droppable, loot pickable by others, dead NFT frozen
- [ ] **5.3** Test cross-temple flow: enter temple A -> level up -> exit -> enter temple B -> verify stats carry over
- [ ] **5.4** Multiplayer testing: two explorers in same temple, verify shared chamber state, shared monster kills, shared chamber generation
- [ ] **5.5** Test boss probability: verify Yonder Formula produces expected distribution over many runs
- [ ] **5.6** Test all three classes through full temple runs, verify class features work correctly
- [ ] **5.7** Balance tuning: adjust monster stats, XP rewards, treasure distribution, trap DCs, boss probability constants
- [ ] **5.8** Edge case testing: death at level 1 with empty inventory, chamber with many fallen explorers, dead-end chambers, exiting temple mid-combat
- [ ] **5.9** Deploy contracts to Starknet testnet (Sepolia) via `sozo migrate --profile sepolia` (requires `dojo_sepolia.toml` with funded account)
- [ ] **5.10** Configure Torii indexer on testnet, verify GraphQL queries return correct state
- [ ] **5.11** Smoke test the full flow on testnet with live VRF
- [ ] **5.12** Document setup instructions, known limitations, and tuning constants
