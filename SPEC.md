# D20 On-Chain: Spec Document

## Overview

A fully on-chain text-based RPG built on Starknet using Cairo and the Dojo framework. The game implements a subset of the D20 SRD as smart contracts — the contracts act as the rules engine and referee. There is no central game server. Players interact through a local AI agent (LLM-powered) that translates natural language into contract calls and narrates the results as a story.

## CRITICAL: Cairo Integer-Only Arithmetic

**Cairo has no floating point numbers.** All arithmetic in the contracts must use integer math only. This affects every calculation in the game:

- **Ability modifier**: `(score - 10) / 2` — integer division, rounds toward zero. A score of 11 gives +0, not +0.5.
- **Damage halving** (e.g., Uncanny Dodge): always round down. `7 / 2 = 3`, not 3.5.
- **Probability calculations**: use basis points (bps, 0–10000) instead of percentages or decimals. 50% = 5000 bps.
- **All division must happen last** in any formula to minimize precision loss. Always multiply before dividing.
- **Scaling pattern**: when a formula would naturally produce fractions, multiply all terms by a common scale factor first, perform the math, then divide at the end.

Every formula in this spec is written with integer math in mind. When implementing, always verify that intermediate values don't overflow (`u128`, `u256`) and that division truncation doesn't produce unexpected zeros.

---

## Architecture

```
┌─────────────────────────────────┐
│        Explorer Client          │
│  ┌───────────┐  ┌────────────┐  │
│  │ Chat UI   │  │ AI Agent   │  │
│  │ (frontend)│◄►│ (LLM)     │  │
│  └───────────┘  └─────┬──────┘  │
│                       │         │
└───────────────────────┼─────────┘
                        │ reads state via Torii (GraphQL)
                        │ submits txns to World contract
                        ▼
┌─────────────────────────────────┐
│        Starknet (Dojo)          │
│                                 │
│  ┌──────────┐  ┌─────────────┐  │
│  │  Models  │  │  Systems    │  │
│  │ (state)  │◄─│ (D20 rules) │  │
│  └──────────┘  └─────────────┘  │
│                                 │
│  NFT Contracts (ERC-721)        │
│  ├─ Explorer NFT                │
│  └─ Temple NFT                  │
│                                 │
│  Cartridge VRF (randomness)     │
│  World Contract (Dojo)          │
│  Torii Indexer                  │
│  Katana Sequencer (dev)         │
└─────────────────────────────────┘
```

**No game master server.** The contracts enforce all rules. The AI agent on the explorer's client side does two things:
1. Translates natural language ("I try to sneak past the guard") into the correct contract call (`skill_check(stealth, guard_id)`)
2. Reads on-chain results and narrates them as a story ("You press against the wall as the torchlight sweeps past...")

---

## NFT System

All NFTs use dedicated ERC-721 contracts built with **OpenZeppelin ERC-721 components** and **[cairo-nft-combo](https://github.com/underware-gg/cairo-nft-combo)**.

**cairo-nft-combo** provides:
- `_mint_next()` — sequential minting with an internal counter (no need for `world.uuid()`)
- Supply management (`max_supply`, `minted_supply`, `available_supply`)
- On-chain metadata rendering via `ERC721ComboHooksTrait`
- ERC-7572, ERC-4906, ERC-2981 extensions

**Token IDs** are `u256` (OpenZeppelin standard). The internal counter auto-increments on each `_mint_next()` call. All Dojo models use `u128` keys — conversion: `let explorer_id: u128 = token_id.low;` (high part is always 0 for counter-minted IDs).

### Explorer NFT
- Each explorer is an NFT minted when a player creates a character
- The token ID (`u128`) is the primary key for all explorer-related models
- An explorer NFT represents a unique character with stats, inventory, and history
- **Permadeath:** When an explorer dies, the NFT is frozen permanently. The explorer's body remains visible at the chamber where they fell. A dead explorer can never be used again — the player must mint a new explorer to continue playing.
- The explorer tracks how many temples they have conquered (killed the boss)

### Temple NFT
- Each temple is an NFT representing a procedurally generated world
- The temple token ID is the key for all chamber data and world state
- Temples are minted with a seed that determines their generation rules
- Multiple temples can exist — explorers choose which temple to enter
- An explorer can be inside at most one temple at a time, or none (freshly minted / between temples)
- Explorers can exit a temple and enter another — this creates interesting cross-temple strategy where you level up in an easier temple to tackle a harder one

### Future: Equipment/Item NFTs
- A future feature will allow players to bring player-owned NFTs into the game that grant special advantages (e.g., a legendary sword NFT gives +2 to attack rolls)
- Out of scope for v1

---

## Character Creation

When a player mints an Explorer NFT, they go through the following steps:

1. **Choose a class:** Fighter, Rogue, or Wizard. This determines hit die, starting equipment, skill proficiencies, saving throw proficiencies, and class features.

2. **Assign ability scores:** The player receives the standard array `[15, 14, 13, 12, 10, 8]` and assigns each value to one of the six ability scores (STR, DEX, CON, INT, WIS, CHA). The assignment is a strategic decision based on class — a Fighter wants high STR and CON, a Rogue wants high DEX, a Wizard wants high INT.

3. **Choose skill proficiencies:** Each class grants proficiency in a fixed number of skills. The player selects from the class's skill list:
   - **Fighter:** Athletics is automatic, plus 1 choice from [Perception, Acrobatics]
   - **Rogue:** Stealth and Acrobatics are automatic, plus 2 choices from [Perception, Persuasion, Athletics, Arcana]. Rogue also picks 2 skills for Expertise (double proficiency bonus).
   - **Wizard:** Arcana is automatic, plus 1 choice from [Perception, Persuasion]

4. **Initialization:** The contract mints the Explorer NFT, sets starting HP (hit die max + CON modifier), assigns starting equipment and AC based on class, and places the explorer in the "no temple" state (ready to enter a temple).

All of this happens in a single `mint_explorer` transaction. The parameters are: `class`, `stat_assignment` (array of 6 values mapping to ability scores), and `skill_choices` (array of skill enum values for the optional proficiency picks, plus expertise picks for Rogue).

---

## Core D20 Mechanics to Implement

### The Universal Mechanic
Everything resolves as: **d20 + modifier >= target number (DC or AC)**

### Ability Scores
Six scores per explorer: STR, DEX, CON, INT, WIS, CHA
- Range: 3-20
- Modifier formula: `floor((score - 10) / 2)` — always rounds **down** (floor division), matching the SRD. Returns `i8`. Implementation: `if score >= 10 { ((score - 10) / 2).try_into().unwrap() } else { -(((11 - score) / 2).try_into().unwrap()) }`. Verification: score 9 → -1 ✓, score 8 → -1 ✓, score 7 → -2 ✓, score 10 → 0 ✓, score 11 → 0 ✓, score 12 → +1 ✓.
- Character creation: standard array [15, 14, 13, 12, 10, 8] assigned by player

### Proficiency Bonus
Flat bonus based on level:
| Level | Bonus |
|-------|-------|
| 1     | +2    |
| 2     | +2    |
| 3     | +2    |
| 4     | +2    |
| 5     | +3    |

### Skills (subset)
Each skill is tied to an ability score. An explorer can be proficient in some skills (adds proficiency bonus).

| Skill        | Ability | Used for                  |
|-------------|---------|---------------------------|
| Athletics   | STR     | Climbing, jumping, grappling |
| Stealth     | DEX     | Sneaking, hiding          |
| Perception  | WIS     | Noticing things, spotting traps |
| Persuasion  | CHA     | Convincing NPCs           |
| Arcana      | INT     | Magic knowledge, identifying spells |
| Acrobatics  | DEX     | Balance, dodging           |

**Skill check**: `d20 + ability_modifier + (proficiency_bonus if proficient) >= DC`

### Combat

**Initiative**: `d20 + DEX modifier` — determines turn order.

**Attack roll**: `d20 + ability_modifier + proficiency_bonus >= target AC`
- Melee attacks use STR modifier
- Ranged attacks use DEX modifier
- Natural 20 = critical hit (double damage dice)
- Natural 1 = automatic miss

**Armor Class (AC)**: Depends on armor type:
- No armor: `10 + DEX modifier`
- Leather: `11 + DEX modifier`
- Chain Mail: `16` (no DEX bonus)
- Shield adds `+2` to any of the above (tracked separately via `has_shield`)

**Damage roll**: weapon damage die + ability modifier
| Weapon      | Damage | Type     | Properties |
|-------------|--------|----------|------------|
| Longsword   | 1d8    | Slashing | Melee, STR |
| Dagger      | 1d4    | Piercing | Melee/Thrown, DEX or STR |
| Shortbow    | 1d6    | Piercing | Ranged, DEX |
| Greataxe    | 1d12   | Slashing | Melee, STR, two-handed |
| Staff       | 1d6    | Bludgeoning | Melee, STR |

**Saving Throws**: `d20 + ability_modifier + (proficiency_bonus if proficient) >= DC`
Used to resist effects (traps, spells, poison, etc.)

### Hit Points
- Determined at creation by class hit die max + CON modifier
- Gain HP each level: roll hit die (or take average) + CON modifier
- At 0 HP: **permadeath** (see Death section)

### Classes (3 for v1)

**Fighter**
- Hit die: d10
- Proficient saves: STR, CON
- Proficient skills: Athletics + 1 choice
- Starting equipment: Longsword, Chain Mail (AC 16)
- Features:
  - Level 1: Second Wind (bonus action, heal 1d10 + level, once per rest)
  - Level 2: Action Surge (take an extra action, once per rest)
  - Level 3: Champion subclass — crit on 19 or 20
  - Level 5: Extra Attack (two attacks per turn)

**Rogue**
- Hit die: d8
- Proficient saves: DEX, INT
- Proficient skills: Stealth, Acrobatics + 2 choices
- Starting equipment: Dagger (primary), Shortbow (secondary), Leather Armor (AC 11 + DEX)
- Features:
  - Level 1: Sneak Attack (extra damage when you have advantage; 1d6 at levels 1-2, 2d6 at levels 3-4, 3d6 at level 5)
  - Level 1: Expertise (double proficiency bonus on 2 skills)
  - Level 2: Cunning Action (dash, disengage, or hide as bonus action)
  - Level 5: Uncanny Dodge (halve damage from one attack)

**Wizard**
- Hit die: d6
- Proficient saves: INT, WIS
- Proficient skills: Arcana + 1 choice
- Starting equipment: Staff, no armor (AC 10 + DEX)
- Spell slots:
  | Level | Cantrips | 1st | 2nd | 3rd |
  |-------|----------|-----|-----|-----|
  | 1     | 3        | 2   | -   | -   |
  | 2     | 3        | 3   | -   | -   |
  | 3     | 3        | 4   | 2   | -   |
  | 4     | 4        | 4   | 3   | -   |
  | 5     | 4        | 4   | 3   | 2   |

- Spells (v1 subset):
  - Cantrips: Fire Bolt (1d10 ranged), Mage Hand (utility), Light (utility)
  - 1st level: Magic Missile (3x 1d4+1, auto-hit), Shield (+5 AC reaction), Sleep (5d8 HP of creatures)
  - 2nd level: Scorching Ray (3x 2d6 ranged attack rolls), Misty Step (teleport 30ft)
  - 3rd level: Fireball (8d6 DEX save, AOE)

### Leveling / XP
Simple milestone XP thresholds:
| Level | XP Required |
|-------|-------------|
| 1     | 0           |
| 2     | 300         |
| 3     | 900         |
| 4     | 2,700       |
| 5     | 6,500       |

XP is awarded for defeating monsters (based on CR) and completing objectives.

### Monsters (v1 set — Ancient Temple theme)

All monsters are from the **SRD 5.1 (CC-BY-4.0)**. Selected for thematic fit with ancient temple exploration.

**CR scaling:** Cairo has no fractions. CR is stored as `cr_x4: u8` (CR multiplied by 4). So CR 1/8 = 0, CR 1/4 = 1, CR 1/2 = 2, CR 1 = 4, CR 2 = 8, etc. This is only used for XP calculation and encounter difficulty.

| Monster          | AC | HP  | Attack              | Damage          | Special                                                        | CR   | cr_x4 | XP   | STR | DEX | CON | INT | WIS | CHA |
|-----------------|-----|-----|---------------------|-----------------|----------------------------------------------------------------|------|--------|------|-----|-----|-----|-----|-----|-----|
| Poisonous Snake | 13  | 2   | Bite +5             | 1d1+0 piercing  | DC 10 CON save or 2d4 poison damage                            | 1/8  | 0      | 25   | 2   | 16  | 11  | 1   | 10  | 3   |
| Skeleton        | 13  | 13  | Shortsword +4       | 1d6+2           | —                                                              | 1/4  | 1      | 50   | 10  | 14  | 15  | 6   | 8   | 5   |
| Shadow          | 12  | 16  | Strength Drain +4   | 2d6+2 necrotic  | Target STR reduced by 1d4 on hit; dies if STR reaches 0       | 1/2  | 2      | 100  | 6   | 14  | 13  | 6   | 10  | 8   |
| Animated Armor  | 18  | 33  | Slam +4 (×2)        | 1d6+2           | Multiattack (two slams per turn)                               | 1    | 4      | 200  | 14  | 11  | 13  | 1   | 3   | 1   |
| Gargoyle        | 15  | 52  | Bite +4 / Claws +4  | 1d6+2 / 1d6+2   | Multiattack (bite + claws); resistant to nonmagical physical   | 2    | 8      | 450  | 15  | 11  | 16  | 6   | 11  | 7   |
| Mummy           | 11  | 58  | Rotting Fist +5     | 2d6+3           | DC 12 CON save or mummy rot curse; Dreadful Glare: DC 11 WIS save or frightened | 3    | 12     | 700  | 16  | 8   | 15  | 6   | 10  | 12  |
| Wraith          | 13  | 67  | Life Drain +6       | 4d8+3 necrotic  | DC 14 CON save or max HP reduced by damage dealt; incorporeal | 5    | 20     | 1800 | 6   | 16  | 16  | 12  | 14  | 15  |

Monster ability scores are used for saving throws and contested checks (e.g., monster STR vs explorer STR for grapple). Monster stats are stored as **compile-time constants** in a lookup function, not as mutable models — they're templates instantiated into `MonsterInstance` models when a chamber is generated.

**Thematic progression as explorers go deeper:**
- **Entrance (yonder 0-2):** Poisonous Snakes nesting in overgrown cracks, Skeletons of former worshippers
- **Outer chambers (yonder 3-5):** Shadows lurking in dark corridors, Animated Armor standing vigil at sealed doors
- **Inner sanctum (yonder 6-9):** Gargoyles perched on pillars awakening, Mummies in sealed sarcophagi
- **Boss chamber:** Wraith — the spirit of the temple's high priest, still guarding the sacred heart
---

## Randomness: Cartridge VRF

All dice rolls use the **Cartridge VRF (Verifiable Random Function)** service for on-chain randomness.

### How it works
1. The game contract calls `request_random(caller, source)` as the first call in the explorer's multicall
2. The Cartridge VRF server generates a random value using the VRF algorithm for the provided entropy source
3. The Cartridge Paymaster wraps the explorer's multicall with `submit_random` and `assert_consumed` calls
4. The game contract calls `consume_random(source)` on the VRF contract to get the verified random value
5. The VRF Proof is verified on-chain, ensuring the integrity of the random value

### D20 Roll Implementation

Inside a `#[dojo::contract]`, the VRF is accessed through the world storage. The Cartridge Paymaster injects the random value into the transaction automatically.

```cairo
// In a #[dojo::contract] system:
fn roll_d20(ref world: WorldStorage) -> u8 {
    let seed: felt252 = world.uuid().into(); // unique entropy source
    let random: u256 = vrf.consume_random(seed);
    ((random % 20) + 1).try_into().unwrap()   // 1-20
}

fn roll_dice(ref world: WorldStorage, sides: u8, count: u8) -> u16 {
    let mut total: u16 = 0;
    let mut i: u8 = 0;
    while i < count {
        let seed: felt252 = world.uuid().into();
        let random: u256 = vrf.consume_random(seed);
        total += ((random % sides.into()) + 1).try_into().unwrap();
        i += 1;
    };
    total
}
```

All rolls — ability checks, attack rolls, saving throws, damage dice, initiative — go through Cartridge VRF. This ensures every roll is atomic (resolved in the same transaction as the action), verifiable, and tamper-proof.

### References
- **Cartridge VRF Docs:** https://docs.cartridge.gg/vrf/overview
- **Cartridge VRF GitHub:** https://github.com/cartridge-gg/vrf

---

## Dojo Architecture

### Namespace

All resources live under the **`d20_0_1`** namespace. This replaces the default `dojo_starter` namespace from the template.

```toml
# dojo_dev.toml
[namespace]
default = "d20_0_1"

[writers]
"d20_0_1" = ["d20_0_1-explorer_token", "d20_0_1-combat_system", "d20_0_1-temple_token"]
```

### Models (Components)

All models use the Dojo 1.8+ `#[dojo::model]` attribute

#### Config (singleton)

```cairo
/// Singleton world configuration. Always read/written with key = 1.
/// Stored in src/models/config.cairo.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Config {
    #[key]
    pub key: u8,                      // always 1 — singleton
    pub vrf_address: ContractAddress, // Cartridge VRF provider address
}
```

`Config` is written once by `combat_system`'s `dojo_init(vrf_address)`, which is called automatically by Dojo when the contract is deployed. The VRF address is passed as `init_call_args` in the dojo profile toml files:
- `dojo_dev.toml` / `dojo_release.toml`: Cartridge VRF address (`0x051fea...ced8f`)
- Tests: address of a `MockVrf` contract deployed via `deploy_syscall`, passed as `with_init_calldata` on the `ContractDef`

All dice-rolling functions in `utils/d20.cairo` (`roll_d20`, `roll_dice`) now accept `vrf_address: ContractAddress` as their first parameter instead of hardcoding the constant. Systems read `Config` once at the start of each function call.

 (not the old `#[derive(Model)]`). Every model requires `#[derive(Drop, Serde)]` at minimum. Models with all-primitive fields add `Copy`. Custom nested types (enums, structs) must derive `Introspect`, `DojoStore`, and `Default`.

**Signed integers where D20 demands them.** The D20 system has many naturally negative values: ability modifiers (score 8 → -1), initiative rolls with negative DEX mods, and damage calculations. Cairo supports `i8`, `i16`, `i32`, `i64`, `i128` — use them where the game logic requires negative values. Store HP as `i16` (can go negative to detect overkill), modifiers as `i8` (range -5 to +5 for our score range). Keep unsigned types for values that are never negative (XP, gold, level, ability scores themselves).

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerStats {
    #[key]
    pub explorer_id: u128,    // Explorer NFT token ID (from cairo-nft-combo _mint_next())
    // Ability scores (each 3-20)
    pub strength: u8,
    pub dexterity: u8,
    pub constitution: u8,
    pub intelligence: u8,
    pub wisdom: u8,
    pub charisma: u8,
    // Progression
    pub level: u8,
    pub xp: u32,
    pub class: ExplorerClass,
    // Achievements
    pub temples_conquered: u16,   // how many temple bosses killed
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerHealth {
    #[key]
    pub explorer_id: u128,
    pub current_hp: i16,      // signed — can go negative (overkill detection, then clamped to 0)
    pub max_hp: u16,
    pub is_dead: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerCombat {
    #[key]
    pub explorer_id: u128,
    pub armor_class: u8,
    // Class resources
    pub spell_slots_1: u8,
    pub spell_slots_2: u8,
    pub spell_slots_3: u8,
    pub second_wind_used: bool,
    pub action_surge_used: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerInventory {
    #[key]
    pub explorer_id: u128,
    pub primary_weapon: WeaponType,
    pub secondary_weapon: WeaponType,   // Rogue starts with Dagger + Shortbow
    pub armor: ArmorType,
    pub has_shield: bool,               // +2 AC, separate from armor
    pub gold: u32,
    pub potions: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerPosition {
    #[key]
    pub explorer_id: u128,
    pub temple_id: u128,      // 0 if not in any temple
    pub chamber_id: u32,      // 0 if not in any temple
    pub in_combat: bool,
    pub combat_monster_id: u32,   // MonsterInstance key within chamber (0 if not in combat)
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerSkills {
    #[key]
    pub explorer_id: u128,
    // Proficiency flags for each skill
    pub athletics: bool,
    pub stealth: bool,
    pub perception: bool,
    pub persuasion: bool,
    pub arcana: bool,
    pub acrobatics: bool,
    // Expertise (double proficiency, Rogue feature)
    pub expertise_1: Skill,
    pub expertise_2: Skill,
}

// Tracks an explorer's progress within a specific temple (composite key)
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ExplorerTempleProgress {
    #[key]
    pub explorer_id: u128,
    #[key]
    pub temple_id: u128,
    pub chambers_explored: u16,   // how many chambers this explorer has opened
    pub xp_earned: u32,           // XP earned in this temple (used for boss probability)
}

// Chamber structure — split from monster/environment state for ECS cleanliness.
// This model stores structural data only.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Chamber {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    pub chamber_type: ChamberType,
    pub yonder: u8,               // distance from entrance (0 = entrance)
    pub exit_count: u8,           // number of exits from this chamber
    pub is_revealed: bool,        // whether this chamber has been generated
    pub treasure_looted: bool,
    pub trap_disarmed: bool,
    pub trap_dc: u8,              // 0 if no trap
}

// Separate model for monster instances in chambers.
// Allows a chamber to have one monster (v1) and cleanly extends to multiple (v2).
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MonsterInstance {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    #[key]
    pub monster_id: u32,          // sequential ID within chamber (1 for v1)
    pub monster_type: MonsterType,
    pub current_hp: i16,          // signed — can go negative (overkill), then clamped
    pub max_hp: u16,
    pub is_alive: bool,
}

// Each exit from a chamber. Chambers can have 0 to N exits.
// Chambers are aware of each other through these bidirectional links.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ChamberExit {
    #[key]
    pub temple_id: u128,
    #[key]
    pub from_chamber_id: u32,
    #[key]
    pub exit_index: u8,           // 0, 1, 2, ... up to exit_count-1
    pub to_chamber_id: u32,       // the chamber this exit leads to (0 if unexplored)
    pub is_discovered: bool,      // true once an explorer has opened this exit
}

// Tracks fallen explorers in a chamber.
// A single chamber can contain many fallen explorers.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct FallenExplorer {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    #[key]
    pub fallen_index: u32,        // sequential index per chamber
    pub explorer_id: u128,        // the dead explorer's token ID
    // Dropped loot
    pub dropped_weapon: WeaponType,
    pub dropped_armor: ArmorType,
    pub dropped_gold: u32,
    pub dropped_potions: u8,
    pub is_looted: bool,          // true once another explorer picks up the loot
}

// Counter for how many explorers have fallen in a chamber
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ChamberFallenCount {
    #[key]
    pub temple_id: u128,
    #[key]
    pub chamber_id: u32,
    pub count: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TempleState {
    #[key]
    pub temple_id: u128,          // Temple NFT token ID (from cairo-nft-combo _mint_next())
    pub seed: felt252,
    pub difficulty_tier: u8,
    pub next_chamber_id: u32,     // auto-incrementing ID for new chambers
    pub boss_chamber_id: u32,     // 0 until boss chamber is generated
    pub boss_alive: bool,
}
```

### Enums

All enums stored in Dojo models must derive `Introspect`, `DojoStore`, and `Default` (in addition to `Serde`, `Copy`, `Drop`). The `Default` variant is the first listed variant (or explicitly annotated with `#[default]`).

```cairo
#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ExplorerClass {
    #[default]
    None,
    Fighter,
    Rogue,
    Wizard,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum Skill {
    #[default]
    None,
    Athletics,
    Stealth,
    Perception,
    Persuasion,
    Arcana,
    Acrobatics,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AbilityScore {
    #[default]
    None,
    Strength,
    Dexterity,
    Constitution,
    Intelligence,
    Wisdom,
    Charisma,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum WeaponType {
    #[default]
    None,
    Longsword,    // 1d8 slashing, melee, STR
    Dagger,       // 1d4 piercing, melee/thrown, DEX or STR
    Shortbow,     // 1d6 piercing, ranged, DEX
    Greataxe,     // 1d12 slashing, melee, STR, two-handed
    Staff,        // 1d6 bludgeoning, melee, STR
}

// ArmorType does NOT include Shield — shields are tracked separately
// via `has_shield: bool` on ExplorerInventory. In D&D, shields stack
// with armor (e.g., Chain Mail + Shield = AC 18).
#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ArmorType {
    #[default]
    None,         // AC 10 + DEX mod
    Leather,      // AC 11 + DEX mod
    ChainMail,    // AC 16 (no DEX bonus)
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DamageType {
    #[default]
    None,
    Slashing,
    Piercing,
    Bludgeoning,
    Fire,
    Cold,
    Lightning,
    Force,
    Necrotic,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ChamberType {
    #[default]
    None,
    Entrance,     // starting chamber, safe
    Empty,        // nothing special
    Monster,      // contains a monster encounter
    Treasure,     // contains loot
    Trap,         // contains a trap
    Boss,         // the boss chamber (generated probabilistically)
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum MonsterType {
    #[default]
    None,
    PoisonousSnake,  // CR 0
    Skeleton,        // CR 1
    Shadow,          // CR 2
    AnimatedArmor,   // CR 4
    Gargoyle,        // CR 8
    Mummy,           // CR 12
    Wraith,          // CR 20 -- boss tier
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum SpellId {
    #[default]
    None,
    // Cantrips
    FireBolt,
    MageHand,
    Light,
    // 1st level
    MagicMissile,
    ShieldSpell,
    Sleep,
    // 2nd level
    ScorchingRay,
    MistyStep,
    // 3rd level
    Fireball,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum CombatAction {
    #[default]
    None,
    Attack,
    CastSpell,
    UseItem,
    Flee,
    Dodge,
    SecondWind,     // Fighter
    CunningAction,  // Rogue
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum ItemType {
    #[default]
    None,
    HealthPotion,   // heals 2d4+2
}
```

### Systems (Dojo Contracts)

Systems are `#[dojo::contract]` modules, not free functions. Each contract has an `#[starknet::interface]` trait. Helper functions (dice math, modifiers) live in a shared utility module imported by the contracts.

**Contract layout** — 3 contracts to minimize permission complexity:

| Contract | Tag | Writes to |
|----------|-----|-----------|
| `explorer_token` | `d20_0_1-explorer_token` | ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory, ExplorerSkills |
| `combat_system` | `d20_0_1-combat_system` | ExplorerHealth, ExplorerCombat, ExplorerInventory, ExplorerPosition, MonsterInstance, FallenExplorer, ChamberFallenCount |
| `temple_token` | `d20_0_1-temple_token` | ExplorerPosition, ExplorerTempleProgress, ExplorerStats, ExplorerHealth, ExplorerInventory, TempleState, Chamber, MonsterInstance, ChamberExit, FallenExplorer, ChamberFallenCount |

```cairo
// ──────────────────────────────────────────────
// Shared utility module (not a contract — pure functions)
// Located at src/utils/d20.cairo
// ──────────────────────────────────────────────
// These are helper functions imported by the contracts above.
// They do NOT access the world — they take values and return values.
fn roll_d20(ref world: WorldStorage) -> u8            // consume VRF, mod 20 + 1
fn roll_dice(ref world: WorldStorage, sides: u8, count: u8) -> u16
fn ability_modifier(score: u8) -> i8                  // D20 modifier: (score-10)/2, range -1 to +5
fn proficiency_bonus(level: u8) -> u8
fn calculate_ac(armor: ArmorType, has_shield: bool, dex_mod: i8) -> u8

// NOTE on signed math: when adding i8 modifier to u8 roll, cast to i16 first:
//   let result: i16 = roll.into() + modifier.into();
//   let clamped: u8 = if result < 1 { 1 } else { result.try_into().unwrap() };
// This handles negative modifiers naturally without bool/abs gymnastics.

// ──────────────────────────────────────────────
// explorer_token contract
// ──────────────────────────────────────────────
#[starknet::interface]
trait IExplorerActions<T> {
    fn mint_explorer(
        ref self: T,
        class: ExplorerClass,
        stat_assignment: Span<u8>,      // 6 values mapping to [STR, DEX, CON, INT, WIS, CHA]
        skill_choices: Span<Skill>,     // optional proficiency picks
        expertise_choices: Span<Skill>, // Rogue only: 2 skills for double proficiency
    ) -> u128;  // returns explorer token ID

    fn rest(ref self: T, explorer_id: u128);  // restore HP, spell slots, class features
}

// gain_xp and level_up are internal helpers called by combat/temple systems,
// not exposed as external entry points. They live in an InternalImpl.

// ──────────────────────────────────────────────
// combat_system contract
// ──────────────────────────────────────────────
#[starknet::interface]
trait ICombatActions<T> {
    fn attack(ref self: T, explorer_id: u128);
    fn cast_spell(ref self: T, explorer_id: u128, spell_id: SpellId);
    fn use_item(ref self: T, explorer_id: u128, item_type: ItemType);
    fn flee(ref self: T, explorer_id: u128);   // contested DEX check
    fn second_wind(ref self: T, explorer_id: u128);   // Fighter: heal 1d10+level
    fn cunning_action(ref self: T, explorer_id: u128); // Rogue: disengage/hide
}

// Death logic is an internal function called when HP reaches 0:
// - sets is_dead = true on ExplorerHealth
// - creates FallenExplorer with dropped loot in current chamber
// - increments ChamberFallenCount
// - emits ExplorerDied event

// ──────────────────────────────────────────────
// temple_token contract
// ──────────────────────────────────────────────
#[starknet::interface]
trait ITempleActions<T> {
    fn mint_temple(ref self: T, seed: felt252, difficulty: u8) -> u128;
    fn enter_temple(ref self: T, explorer_id: u128, temple_id: u128);
    fn exit_temple(ref self: T, explorer_id: u128);
    fn open_exit(ref self: T, explorer_id: u128, exit_index: u8);
    fn move_to_chamber(ref self: T, explorer_id: u128, exit_index: u8);
    fn disarm_trap(ref self: T, explorer_id: u128);      // DEX/skill check
    fn loot_treasure(ref self: T, explorer_id: u128);    // Perception check + loot pickup
    fn loot_fallen(ref self: T, explorer_id: u128, fallen_index: u32);
}

// generate_chamber and calculate_boss_probability are internal helpers,
// not exposed as external entry points.
```

### Events

Events are critical for Torii indexing and for the AI agent to narrate outcomes. All events use `#[dojo::event]` and are emitted via `world.emit_event(...)`.

```cairo
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExplorerMinted {
    #[key]
    pub explorer_id: u128,
    pub class: ExplorerClass,
    pub player: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct CombatResult {
    #[key]
    pub explorer_id: u128,
    pub action: CombatAction,
    pub roll: u8,
    pub damage_dealt: u16,
    pub damage_taken: u16,
    pub monster_killed: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ExplorerDied {
    #[key]
    pub explorer_id: u128,
    pub temple_id: u128,
    pub chamber_id: u32,
    pub killed_by: MonsterType,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ChamberRevealed {
    #[key]
    pub temple_id: u128,
    pub chamber_id: u32,
    pub chamber_type: ChamberType,
    pub yonder: u8,
    pub revealed_by: u128,    // explorer who opened the exit
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct LevelUp {
    #[key]
    pub explorer_id: u128,
    pub new_level: u8,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct BossDefeated {
    #[key]
    pub temple_id: u128,
    pub explorer_id: u128,
    pub monster_type: MonsterType,
}
```

---

## Chamber Generation: Fog of War

Chambers are **not** pre-generated. They are created one at a time as explorers open exits. The temple starts with only its entrance chamber. Everything beyond is unknown.

### How it works

1. **Temple minting** creates a single entrance chamber (chamber_id=1, yonder=0, type=Entrance). The entrance has a random number of exits (determined by seed) leading to unexplored space.

2. **Opening an exit** triggers `generate_chamber`. The new chamber is created from the temple seed combined with the chamber's position in the graph. This determines:
   - **Chamber type**: Monster, Treasure, Trap, Empty, or Boss (see boss probability below)
   - **Number of exits**: 0 to 3 (a dead end has 0 exits beyond the one you came from)
   - **Yonder value**: parent chamber's yonder + 1
   - **Monster type and stats**: based on difficulty tier and yonder
   - **Trap DC**: based on difficulty tier and yonder

3. **Bidirectional linking**: When a new chamber is generated, both the ChamberExit from the parent and a new ChamberExit back to the parent are created. Chambers always know how to reach each other.

4. **Dead ends**: A chamber with 0 new exits (only the one back to the parent) is a dead end. The explorer must backtrack.

5. **The boss is always a surprise.** The boss chamber's location is determined probabilistically when a new chamber is generated. Until it appears, no one knows how deep the temple goes.

---

## Boss Chamber Probability: The Yonder Formula

When a new chamber is generated, the system calculates the probability that it becomes the **Boss Chamber**. This probability increases with three factors:

- **Yonder (y)**: Distance from the entrance. The deeper you go, the more likely the boss appears.
- **Chambers explored (c)**: How many chambers the explorer who opened this exit has explored in this temple.
- **XP earned (x)**: How much XP the explorer has earned in this temple, as a proxy for "experience" (combat survived, challenges overcome).

### The Formula (Integer-Only, Cairo-Safe)

**All math uses integer arithmetic only.** Probabilities are expressed in basis points (bps): 0 = 0%, 10000 = 100%. Multiplication is always done before division to avoid truncating to zero.

```
// Constants (tunable)
MIN_YONDER: u8 = 5         // Boss can never appear before yonder 5
YONDER_WEIGHT: u32 = 50    // bps per effective_yonder² (controls depth scaling)
XP_WEIGHT: u32 = 2         // bps per xp_earned (direct multiplier, no division)
MAX_PROB: u32 = 9500       // Cap at 95% (9500 bps out of 10000)

// Input
yonder: u8                  // distance from entrance
xp_earned: u32              // XP earned in THIS temple

// Calculation (all integer math)
if yonder < MIN_YONDER:
    return 0

effective_yonder: u32 = (yonder - MIN_YONDER).into()

// Quadratic yonder component: slow start, rapid growth at depth
// e.g., eff=1 → 50, eff=5 → 1250, eff=10 → 5000
yonder_component: u32 = effective_yonder * effective_yonder * YONDER_WEIGHT

// Linear XP component: direct multiplication, NO DIVISION
// e.g., xp=150 → 300, xp=800 → 1600, xp=2500 → 5000
xp_component: u32 = xp_earned * XP_WEIGHT

// Final probability in basis points (0–10000)
boss_probability_bps: u32 = min(MAX_PROB, yonder_component + xp_component)
```

**Why `XP_WEIGHT = 2` instead of `(xp / 100) * 200`?** In Cairo, `xp_earned / 100` would truncate to zero for any XP below 100 — which covers most early encounters (Poisonous Snakes give 25 XP, Skeletons give 50 XP). By using `xp_earned * 2` directly, every point of XP contributes to boss probability without any precision loss. The constant `2` is algebraically equivalent to `200 / 100` but safe for integer math.

### Probability Table (examples, assuming XP earned from typical combat)

| Yonder | Eff. Yonder | XP Earned | Yonder bps | XP bps | Total bps | Boss % |
|--------|-------------|-----------|------------|--------|-----------|--------|
| 1-4    | —           | any       | 0          | —      | 0         | 0%     |
| 5      | 0           | 150       | 0          | 300    | 300       | 3%     |
| 7      | 2           | 400       | 200        | 800    | 1000      | 10%    |
| 10     | 5           | 800       | 1250       | 1600   | 2850      | 28.5%  |
| 13     | 8           | 1500      | 3200       | 3000   | 6200      | 62%    |
| 15     | 10          | 2500      | 5000       | 5000   | 9500      | 95% (cap) |
| 18     | 13          | 3000      | 8450       | 6000   | 9500      | 95% (cap) |

### Design Intent
- **Yonder 1-4**: Impossible. The entrance area is always safe to explore.
- **Yonder 5-9**: Unlikely (0-10%). The temple is revealing itself, tension is building.
- **Yonder 10-14**: Moderate (10-60%). Every new exit could be the boss. This is the "danger zone."
- **Yonder 15+**: Near-certain (60-95%). You've gone deep. The boss is waiting.
- **The 5% uncertainty**: Even at 95%, there's always a slim chance the next chamber isn't the boss. Keeps the tension alive.

The quadratic yonder curve means early exploration feels safe and rewarding, while deep exploration becomes increasingly perilous. The XP component ensures that explorers who've been fighting and solving challenges (rather than sneaking past everything) encounter the boss sooner — they've "attracted the temple's attention."

### On-chain Resolution (Cairo-safe)
The boss probability is compared against a VRF roll:
```cairo
let prob_bps: u32 = calculate_boss_probability(temple_id, explorer_id, yonder);
let roll: u32 = (vrf.consume_random(source) % 10000).try_into().unwrap();  // 0-9999
let is_boss: bool = roll < prob_bps;
```

---

## Death & Loot Drop

**Death is permanent.** When an explorer reaches 0 HP:

1. **Explorer dies forever.** The `is_dead` flag is set to true. The Explorer NFT remains on-chain as a permanent record but can never take another action.
2. **Loot drops.** A `FallenExplorer` record is created in the current chamber, containing the explorer's weapon, armor, gold, and potions. The `ChamberFallenCount` is incremented.
3. **The body remains.** Other explorers entering the chamber can see the fallen explorer's body. The AI narrator describes them and their dropped loot.
4. **Loot is first-come-first-served.** Any living explorer in the chamber can call `loot_fallen(explorer_id, fallen_index)` to pick up items. Once looted, `is_looted` is set to true.
5. **Multiple bodies can accumulate.** A particularly deadly chamber might have many fallen explorers, each with their own loot. This creates "loot graveyards" that attract other explorers.
6. **MAYBE: Abilities drop too.** Open question — should fallen explorers also drop class abilities or skill proficiencies that other explorers can absorb? This could create interesting "soul harvesting" mechanics but needs careful balancing.

### To play again
The player must mint a new Explorer NFT. They start fresh — level 1, new class choice, new stat assignment. Their previous explorer's body remains in the temple as a permanent monument (and loot piñata).

---

## Temple Traversal

Explorers are not locked into a single temple. The flow is:

1. **Mint explorer** → explorer is in "no temple" state (temple_id = 0, chamber_id = 0)
2. **Enter temple** → explorer is placed at the entrance chamber (yonder = 0)
3. **Explore** → open exits, fight monsters, find loot, go deeper
4. **Exit temple** → explorer returns to "no temple" state. Progress in the temple (opened chambers, killed monsters) persists for everyone. The explorer's personal stats, inventory, and XP are retained.
5. **Enter another temple** → same explorer, different temple. Can be easier or harder.
6. **Conquer a temple** → kill the boss. The explorer's `temples_conquered` counter increments. Explorer can exit and enter new temples.

This creates strategic depth: a player might mint an explorer, grind XP in an easy temple, exit, then enter a hard temple at level 5 with good gear. Or they might rush a hard temple at level 1 for the challenge.

**Constraint:** An explorer can only be in one temple at a time. They must exit before entering another. They always enter from the entrance chamber — you cannot resume at a deep chamber from a previous visit.

---

## Multiplayer

- All explorers in the same temple share world state
- Monster state is global: if an explorer kills the orc in chamber 5, it's dead for everyone
- Chamber generation is global: if an explorer opens an exit, the new chamber exists for everyone
- Treasure and loot are first-come-first-served
- Fallen explorer loot is available to whoever reaches the chamber first
- Explorers can see other explorers' positions and fallen explorer bodies (via Torii queries)
- PvP is out of scope for v1

---

## AI Agent (Client-Side)

The AI agent is NOT part of the on-chain system. It runs locally on the explorer's machine.

**Responsibilities:**
1. Query world state via Torii GraphQL (chamber descriptions, monster info, explorer stats)
2. Accept natural language input from the player
3. Map player intent to the correct system call:
   - "I sneak down the hallway" → `move_to_chamber(explorer_id, exit_index)` then `skill_check(stealth, chamber_dc)`
   - "I attack the Skeleton with my sword" → `attack(explorer_id)`
   - "I cast fireball" → `cast_spell(explorer_id, FIREBALL)`
   - "I search for treasure" → `loot_treasure(explorer_id)` (Perception check + loot pickup)
   - "I check the dead body" → `loot_fallen(explorer_id, fallen_index)`
   - "I open the door on the left" → `open_exit(explorer_id, 1)`
   - "I leave the temple" → `exit_temple(explorer_id)`
4. Read the transaction result (success/fail, damage dealt, HP remaining, etc.)
5. Narrate the outcome in rich, atmospheric text

**Context the agent needs per turn:**
- Explorer's full character sheet (stats, HP, inventory, level, class features)
- Current chamber state (type, yonder, monsters, traps, items, fallen explorers, exits, other live explorers)
- Recent action history (for narrative continuity)
- Available actions given current state (in combat vs exploring)
- Temple progress (chambers explored, temples conquered)

**Tech stack suggestion:** A lightweight wrapper that connects to Torii for reads, uses starknet.js/starknet.py for transaction submission, and calls an LLM API (Claude) for the NL↔action mapping and narration.

---

## 5-Day Build Plan

See **[TASKS.md](TASKS.md)** for the full tickable task list.

---

## Open Questions / Future Scope
- Should fallen explorers drop class abilities / skill proficiencies in addition to items ("soul harvesting")?
- How are temple seeds governed? Open minting by anyone? Curated? Rate-limited?
- Locked exits requiring specific loot items to open (key-and-lock mechanic for branching paths)
- PvP in v2?
- On-chain leaderboard (temples conquered, deepest yonder reached, most monsters killed)?
- Player-deployed autonomous agents (auto-play while AFK)?
- Player-owned NFTs as equipment (bring external NFTs for in-game bonuses)?
- Expanding the D20 subset: more classes, races, feats, levels beyond 5?
- Monster respawn mechanics (do cleared temples eventually refill)?
- Cooperative mechanics: multiple explorers fighting the same monster together?
 
---
 
 ## Agent & Gameplay Documentation
 
 To facilitate interaction for autonomous agents, comprehensive documentation is provided:
 - **[AGENTS.md](AGENTS.md)**: A high-level entry point for agents, explaining game flow and developer guidance.
 - **[GAMEPLAY.md](GAMEPLAY.md)**: A detailed technical reference for all public contract methods, complete with direct source links and mechanic explanations.
 
 ### Documentation Consistency
 
 > [!IMPORTANT]
 > Any changes to the public methods in the underlying contracts (`IExplorerTokenPublic`, `ITempleTokenPublic`, `ICombatSystem`) **MUST** be reflected in [GAMEPLAY.md](GAMEPLAY.md) to keep the agent guidelines accurate. This ensures that agents have a stable and predictable reference for all game actions.
