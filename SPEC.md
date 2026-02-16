# Application Specification

> This file is the source of truth for what we're building.
> Claude reads this to understand the full system and what to build next.
> Mark sections `[x]` as they're implemented. Add details as the design evolves.

---

## Overview

<!-- One paragraph: what is this app? Who is it for? What's the core loop? -->

**Name:** (your game name)
**Genre:** (e.g., strategy, RPG, trading, idle, PvP arena)
**One-liner:** (e.g., "An onchain survival game where players gather resources, craft items, and defend territory")

---

## Game Loop

<!-- Describe the core player experience in 3-5 steps -->

1. Player does X ...
2. Which causes Y ...
3. Leading to Z ...

---

## Contracts (Dojo ECS)

### Models (State)

<!-- Each model is a component attached to entities. Define what state you need. -->

| Model | Keys | Fields | Purpose |
|-------|------|--------|---------|
| `Player` | `player: ContractAddress` | `name: felt252, level: u8, xp: u32` | Core player profile |
| `Health` | `player: ContractAddress` | `current: u32, max: u32` | Player health |
| _add more rows..._ | | | |

### Systems (Logic)

<!-- Each system is a contract that reads/writes models. Define what actions exist. -->

| System | Functions | Models Written | Description |
|--------|-----------|---------------|-------------|
| `actions` | `spawn()`, `move(direction)` | `Position`, `Moves` | Basic movement (already exists) |
| _add more rows..._ | | | |

### Events

<!-- Onchain events emitted by systems, indexed by Torii -->

| Event | Fields | Emitted By | Purpose |
|-------|--------|-----------|---------|
| `Moved` | `player, direction` | `actions::move` | Track movement (already exists) |
| _add more rows..._ | | | |

### Tokens

<!-- ERC20/ERC721 tokens if needed -->

| Token | Standard | Name / Symbol | Purpose |
|-------|----------|--------------|---------|
| _e.g._ | `ERC20` | `Gold / GOLD` | In-game currency |
| _add more rows or remove section..._ | | | |

---

## Client

<!-- How players interact with the game -->

**Platform:** (web / Unity / Unreal / terminal)
**Framework:** (React + dojo.js / Phaser / Godot / etc.)
**Location:** `packages/client/`

### Screens / Views

| Screen | Description | Reads | Writes |
|--------|-------------|-------|--------|
| `Lobby` | Player joins, sees others | `Player` | `spawn()` |
| `Game` | Main gameplay view | `Position`, `Health` | `move()`, `attack()` |
| _add more rows..._ | | | |

### Key Interactions

- **Movement:** WASD/arrows -> calls `actions::move`
- _add more..._

---

## Agents (Autonomous)

<!-- Offchain bots/agents that interact with the world automatically -->

| Agent | Trigger | Actions | Purpose |
|-------|---------|---------|---------|
| _e.g._ `spawner` | Every 30s | Calls `spawn_enemy()` | Keeps the world populated |
| _e.g._ `matchmaker` | On player queue | Pairs players, calls `start_match()` | Automated matchmaking |
| _add more rows or remove section..._ | | | |

**Agent runtime:** (Node.js / Python / Rust)
**Location:** `packages/agents/`

---

## Indexing (Torii)

<!-- What data does the client need to query? -->

### GraphQL Queries

- `players` - List all players with position and stats
- `leaderboard` - Top players by XP/score
- _add more..._

### Subscriptions (Real-time)

- `entityUpdated(Position)` - Live player movement
- _add more..._

---

## Build Order

<!-- Ordered list of implementation steps. Claude works through these top-to-bottom. -->
<!-- Mark [x] when done. Be specific enough that Claude can implement without guessing. -->

- [x] Initialize Dojo project with starter template
- [ ] Step 2: Define core models (list which ones)
- [ ] Step 3: Implement core systems (list which ones)
- [ ] Step 4: Write tests for core systems
- [ ] Step 5: Set up client scaffolding
- [ ] Step 6: Connect client to Torii
- [ ] Step 7: (next milestone...)

---

## Notes

<!-- Anything else: constraints, inspirations, references, open questions -->

- Built on Dojo 1.8.0 / Cairo / StarkNet
- Local dev: Katana (sequencer) + Torii (indexer)
- Deployed via `sozo migrate`
