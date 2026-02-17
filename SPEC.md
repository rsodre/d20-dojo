# D20 On-Chain: Spec Document

## What is the D20 System?

The D20 System is the core rules engine behind Dungeons & Dragons (5th edition). It was released by Wizards of the Coast as the **System Reference Document (SRD 5.1)** under the **Creative Commons Attribution 4.0 International License (CC-BY-4.0)**, making it freely available for anyone to use and build upon.

The entire system revolves around one mechanic: **when the outcome is uncertain, roll a 20-sided die, add a modifier, and compare against a target number.** Every skill check, attack roll, and saving throw in the game reduces to this single resolution formula: `d20 + modifier >= target number`. The richness comes from what modifiers apply (ability scores, proficiency, class features) and what the target number represents (Difficulty Class, Armor Class, spell save DC).

This game implements a focused subset of the D20 SRD as fully on-chain smart contracts on Starknet.

### Reference Sources
- **SRD 5.1 (CC-BY-4.0 PDF):** https://media.wizards.com/2016/downloads/DND/SRD-OGL_V5.1.pdf
- **SRD 5.1 Online Reference:** https://5thsrd.org/
- **SRD on D&D Beyond:** https://www.dndbeyond.com/srd
- **Machine-Readable SRD (GitHub):** https://github.com/Tabyltop/CC-SRD

### Attribution
This work includes material taken from the System Reference Document 5.1 ("SRD 5.1") by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.

---

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

All NFTs use dedicated ERC-721 contracts built with **OpenZeppelin ERC-721 components** and **cairo-nft-combo**.

**Important:** OpenZeppelin's ERC-721 uses `u256` for token IDs. In this game, all token IDs are represented as `u128` — we use only the low part and ignore the high part of the `u256`.

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
- Modifier formula: `(score - 10) / 2` — integer division, always rounds toward zero. **Cairo note:** since scores below 10 produce negative modifiers, use `i8` for the result. Implementation: `if score >= 10 { ((score - 10) / 2) as i8 } else { -((10 - score + 1) / 2) as i8 }` to handle the asymmetry correctly (score 9 → -1, score 8 → -1, score 7 → -2).
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

**Armor Class (AC)**: `10 + DEX modifier + armor_bonus`

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
- Starting equipment: Dagger, Shortbow, Leather Armor (AC 11 + DEX)
- Features:
  - Level 1: Sneak Attack (extra 1d6 damage when you have advantage, scales to 3d6 at level 5)
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

### Monsters (v1 set)

| Monster        | AC | HP  | Attack        | Damage | CR  | XP  |
|---------------|-----|-----|---------------|--------|-----|-----|
| Goblin        | 15  | 7   | Scimitar +4   | 1d6+2  | 1/4 | 50  |
| Skeleton      | 13  | 13  | Shortsword +4 | 1d6+2  | 1/4 | 50  |
| Giant Rat     | 12  | 7   | Bite +4       | 1d4+2  | 1/8 | 25  |
| Orc           | 13  | 15  | Greataxe +5   | 1d12+3 | 1/2 | 100 |
| Ogre          | 11  | 59  | Greatclub +6  | 2d8+4  | 2   | 450 |
| Minotaur      | 14  | 76  | Greataxe +6   | 2d12+4 | 3   | 700 |
| Young Dragon  | 18  | 110 | Bite +10      | 2d10+5 | 5   | 1800|

Each monster also has ability scores (for saves and checks) and a challenge-appropriate DC for any special abilities.

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
```
fn roll_d20(ref vrf: IVRFDispatcher, source: felt252) -> u8 {
    let random = vrf.consume_random(source);
    (random % 20 + 1).try_into().unwrap()
}
```

All rolls — ability checks, attack rolls, saving throws, damage dice, initiative — go through Cartridge VRF. This ensures every roll is atomic (resolved in the same transaction as the action), verifiable, and tamper-proof.

### References
- **Cartridge VRF Docs:** https://docs.cartridge.gg/vrf/overview
- **Cartridge VRF GitHub:** https://github.com/cartridge-gg/vrf

---

## Dojo Architecture

### Models (Components)

```cairo
#[derive(Model)]
struct ExplorerStats {
    #[key]
    explorer_id: u128,    // Explorer NFT token ID
    // Ability scores (each 3-20)
    strength: u8,
    dexterity: u8,
    constitution: u8,
    intelligence: u8,
    wisdom: u8,
    charisma: u8,
    // Progression
    level: u8,
    xp: u32,
    class: ExplorerClass,
    // Achievements
    temples_conquered: u16,   // how many temple bosses killed
}

#[derive(Model)]
struct ExplorerHealth {
    #[key]
    explorer_id: u128,
    current_hp: i16,
    max_hp: u16,
    is_dead: bool,
}

#[derive(Model)]
struct ExplorerCombat {
    #[key]
    explorer_id: u128,
    armor_class: u8,
    initiative: i8,
    // Class resources
    spell_slots_1: u8,
    spell_slots_2: u8,
    spell_slots_3: u8,
    second_wind_used: bool,
    action_surge_used: bool,
}

#[derive(Model)]
struct ExplorerInventory {
    #[key]
    explorer_id: u128,
    weapon: WeaponType,
    armor: ArmorType,
    gold: u32,
    potions: u8,
}

#[derive(Model)]
struct ExplorerPosition {
    #[key]
    explorer_id: u128,
    temple_id: u128,      // 0 if not in any temple
    chamber_id: u32,      // 0 if not in any temple
    in_combat: bool,
    combat_target: u32,   // monster instance id within chamber
}

#[derive(Model)]
struct ExplorerSkills {
    #[key]
    explorer_id: u128,
    // Proficiency flags for each skill
    athletics: bool,
    stealth: bool,
    perception: bool,
    persuasion: bool,
    arcana: bool,
    acrobatics: bool,
    // Expertise (double proficiency, Rogue feature)
    expertise_1: Skill,
    expertise_2: Skill,
}

// Tracks an explorer's progress within a specific temple
#[derive(Model)]
struct ExplorerTempleProgress {
    #[key]
    explorer_id: u128,
    #[key]
    temple_id: u128,
    chambers_explored: u16,   // how many chambers this explorer has opened
    xp_earned: u32,           // XP earned in this temple (used for boss probability)
}

#[derive(Model)]
struct Chamber {
    #[key]
    temple_id: u128,
    #[key]
    chamber_id: u32,
    chamber_type: ChamberType,
    yonder: u8,               // distance from entrance (0 = entrance)
    // Monster state
    monster_type: MonsterType,
    monster_alive: bool,
    monster_current_hp: i16,
    // Environment
    treasure_looted: bool,
    trap_disarmed: bool,
    // Exits (number of exits from this chamber)
    exit_count: u8,
    // Whether this chamber has been generated
    is_revealed: bool,
}

// Each exit from a chamber. Chambers can have 0 to N exits.
// Chambers are aware of each other through these bidirectional links.
#[derive(Model)]
struct ChamberExit {
    #[key]
    temple_id: u128,
    #[key]
    from_chamber_id: u32,
    #[key]
    exit_index: u8,           // 0, 1, 2, ... up to exit_count-1
    to_chamber_id: u32,       // the chamber this exit leads to (0 if unexplored)
    is_discovered: bool,      // true once an explorer has opened this exit
    // Future: locked exits requiring items
    // required_item: ItemType,  // None if no key needed
}

// Tracks fallen explorers in a chamber.
// A single chamber can contain many fallen explorers.
#[derive(Model)]
struct FallenExplorer {
    #[key]
    temple_id: u128,
    #[key]
    chamber_id: u32,
    #[key]
    fallen_index: u32,        // sequential index per chamber
    explorer_id: u128,        // the dead explorer's NFT token ID
    // Dropped loot
    dropped_weapon: WeaponType,
    dropped_armor: ArmorType,
    dropped_gold: u32,
    dropped_potions: u8,
    is_looted: bool,          // true once another explorer picks up the loot
}

// Counter for how many explorers have fallen in a chamber
#[derive(Model)]
struct ChamberFallenCount {
    #[key]
    temple_id: u128,
    #[key]
    chamber_id: u32,
    count: u32,
}

#[derive(Model)]
struct TempleState {
    #[key]
    temple_id: u128,          // Temple NFT token ID
    seed: felt252,
    difficulty_tier: u8,
    next_chamber_id: u32,     // auto-incrementing ID for new chambers
    boss_chamber_id: u32,     // 0 until boss chamber is generated
    boss_alive: bool,
}
```

### Enums

```cairo
#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum ExplorerClass {
    Fighter,
    Rogue,
    Wizard,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum Skill {
    None,
    Athletics,
    Stealth,
    Perception,
    Persuasion,
    Arcana,
    Acrobatics,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum AbilityScore {
    Strength,
    Dexterity,
    Constitution,
    Intelligence,
    Wisdom,
    Charisma,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum WeaponType {
    None,
    Longsword,    // 1d8 slashing, melee, STR
    Dagger,       // 1d4 piercing, melee/thrown, DEX or STR
    Shortbow,     // 1d6 piercing, ranged, DEX
    Greataxe,     // 1d12 slashing, melee, STR, two-handed
    Staff,        // 1d6 bludgeoning, melee, STR
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum ArmorType {
    None,         // AC 10 + DEX
    Leather,      // AC 11 + DEX
    ChainMail,    // AC 16 (no DEX bonus)
    Shield,       // +2 AC (can combine with armor)
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum DamageType {
    Slashing,
    Piercing,
    Bludgeoning,
    Fire,
    Cold,
    Lightning,
    Force,
    Necrotic,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum ChamberType {
    Entrance,     // starting chamber, safe
    Empty,        // nothing special
    Monster,      // contains a monster encounter
    Treasure,     // contains loot
    Trap,         // contains a trap
    Boss,         // the boss chamber (generated probabilistically)
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum MonsterType {
    None,
    Goblin,
    Skeleton,
    GiantRat,
    Orc,
    Ogre,
    Minotaur,
    YoungDragon,  // boss-tier
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum SpellId {
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

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum SpellLevel {
    Cantrip,
    First,
    Second,
    Third,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum CombatAction {
    Attack,
    CastSpell,
    UseItem,
    Flee,
    Dodge,
    SecondWind,     // Fighter
    CunningAction,  // Rogue
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum ItemType {
    None,
    HealthPotion,   // heals 2d4+2
}
```

### Systems (Game Logic)

```
// ──────────────────────────────────────────────
// Core D20 Resolver — used by all other systems
// ──────────────────────────────────────────────
fn roll_d20(ref vrf, source) -> u8
fn roll_dice(ref vrf, source, sides: u8, count: u8) -> u16
fn ability_modifier(score: u8) -> i8
fn proficiency_bonus(level: u8) -> u8
fn skill_check(explorer_id, skill, dc) -> (bool, u8)  // (success, roll)
fn attack_roll(attacker_id, target_id) -> (bool, u8, bool)  // (hit, roll, crit)
fn saving_throw(entity_id, ability, dc) -> (bool, u8)
fn roll_damage(weapon, crit) -> u16

// ──────────────────────────────────────────────
// Explorer System
// ──────────────────────────────────────────────
fn mint_explorer(class, stat_assignment, skill_choices) -> u128  // mints NFT, returns token ID
fn gain_xp(explorer_id, amount)
fn level_up(explorer_id)
fn rest(explorer_id)  // restore HP, spell slots, class features

// ──────────────────────────────────────────────
// Combat System
// ──────────────────────────────────────────────
fn initiate_combat(explorer_id, monster_type)
fn attack(explorer_id)
fn cast_spell(explorer_id, spell_id)
fn use_item(explorer_id, item_type)
fn flee(explorer_id)  // contested DEX check

// ──────────────────────────────────────────────
// Death System — permadeath
// ──────────────────────────────────────────────
fn die(explorer_id)
// - marks explorer as dead (is_dead = true, frozen permanently)
// - creates FallenExplorer record in current chamber with dropped loot
// - increments ChamberFallenCount
// - explorer NFT remains on-chain (visible, never usable again)

// ──────────────────────────────────────────────
// Loot System
// ──────────────────────────────────────────────
fn loot_treasure(explorer_id)                                  // pick up chamber treasure
fn loot_fallen(explorer_id, fallen_index)                      // pick up a fallen explorer's items

// ──────────────────────────────────────────────
// Exploration System
// ──────────────────────────────────────────────
fn open_exit(explorer_id, exit_index)  // generates new chamber if undiscovered
fn move_to_chamber(explorer_id, exit_index)  // move through a discovered exit
fn search_chamber(explorer_id)  // Perception check for hidden traps/treasure
fn disarm_trap(explorer_id)     // DEX check or appropriate skill

// ──────────────────────────────────────────────
// Temple System
// ──────────────────────────────────────────────
fn mint_temple(seed: felt252, difficulty: u8) -> u128  // mints Temple NFT
fn enter_temple(explorer_id, temple_id)  // places explorer in entrance chamber
fn exit_temple(explorer_id)              // removes explorer from temple (can enter another)
fn generate_chamber(temple_id, from_chamber_id, exit_index) -> u32  // creates new chamber
fn calculate_boss_probability(temple_id, explorer_id, yonder) -> u16  // bps
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

**Why `XP_WEIGHT = 2` instead of `(xp / 100) * 200`?** In Cairo, `xp_earned / 100` would truncate to zero for any XP below 100 — which covers most early encounters (Goblins give 50 XP, Giant Rats give 25). By using `xp_earned * 2` directly, every point of XP contributes to boss probability without any precision loss. The constant `2` is algebraically equivalent to `200 / 100` but safe for integer math.

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
   - "I attack the goblin with my sword" → `attack(explorer_id)`
   - "I cast fireball" → `cast_spell(explorer_id, FIREBALL)`
   - "I search for traps" → `search_chamber(explorer_id)` (Perception check)
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

### Day 1: Foundation & Models
- **1.1** Scaffold Dojo project with `sozo init`
- **1.2** Set up Cartridge VRF integration (import VRF contract interface, configure provider)
- **1.3** Define all enums (ExplorerClass, Skill, AbilityScore, WeaponType, ArmorType, DamageType, ChamberType, MonsterType, SpellId, SpellLevel, CombatAction, ItemType)
- **1.4** Implement explorer models (ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory, ExplorerPosition, ExplorerSkills)
- **1.5** Implement temple/chamber models (TempleState, Chamber, ChamberExit, FallenExplorer, ChamberFallenCount, ExplorerTempleProgress)
- **1.6** Implement core D20 resolver functions: `roll_d20`, `roll_dice`, `ability_modifier`, `proficiency_bonus`
- **1.7** Implement skill check, attack roll, and saving throw resolution logic
- **1.8** Write unit tests for all D20 math (modifier calculation, proficiency by level, roll bounds)
- **1.9** Test VRF integration with Katana locally

### Day 2: Explorer & Combat Systems
- **2.1** Set up Explorer NFT contract (OpenZeppelin ERC-721 + cairo-nft-combo, u128 token IDs)
- **2.2** Implement `mint_explorer` system (mint NFT, validate standard array assignment, initialize stats/HP/equipment based on class, set skill proficiencies from choices)
- **2.3** Implement class-specific initialization: Fighter (Longsword, Chain Mail, AC 16, Athletics + choice), Rogue (Dagger, Shortbow, Leather, AC 11+DEX, Stealth/Acrobatics + 2 choices + expertise), Wizard (Staff, no armor, AC 10+DEX, Arcana + choice, spell slots)
- **2.4** Implement basic combat loop: initiative roll, attack rolls vs AC, damage rolls, HP deduction
- **2.5** Implement Fighter features (Second Wind heal, Action Surge extra action, Champion crit on 19-20 at level 3, Extra Attack at level 5)
- **2.6** Implement Rogue features (Sneak Attack bonus dice, Expertise double proficiency, Cunning Action, Uncanny Dodge at level 5)
- **2.7** Implement Wizard spell casting: spell slot tracking per level, cantrip resolution (Fire Bolt attack roll + 1d10), leveled spell resolution (Magic Missile auto-hit 3×1d4+1, Shield +5 AC reaction, Sleep 5d8 HP, Scorching Ray 3×2d6, Misty Step, Fireball 8d6 DEX save)
- **2.8** Implement death system: set `is_dead`, create `FallenExplorer` with loot, increment `ChamberFallenCount`
- **2.9** Implement rest mechanic: restore `current_hp` to `max_hp`, reset spell slots to class/level values, reset `second_wind_used` and `action_surge_used`
- **2.10** Implement `flee` mechanic: contested DEX check, on success move back to previous chamber
- **2.11** Write unit tests for combat math, each class feature, and death flow

### Day 3: Temple & Exploration
- **3.1** Set up Temple NFT contract (OpenZeppelin ERC-721 + cairo-nft-combo, u128 token IDs)
- **3.2** Implement `mint_temple`: mint NFT, create entrance chamber (chamber_id=1, yonder=0, type=Entrance), generate entrance exits from seed
- **3.3** Implement `enter_temple`: validate explorer is alive and not in another temple, place at entrance chamber, initialize `ExplorerTempleProgress`
- **3.4** Implement `exit_temple`: remove explorer from temple (set temple_id=0, chamber_id=0), retain stats/inventory/XP
- **3.5** Implement `generate_chamber`: derive chamber properties from temple seed + chamber position, calculate boss probability via Yonder Formula, determine chamber type / monster type / exit count / trap DC
- **3.6** Implement `open_exit`: call `generate_chamber` for undiscovered exits, create bidirectional `ChamberExit` links, increment `chambers_explored` on `ExplorerTempleProgress`
- **3.7** Implement `move_to_chamber`: validate exit is discovered, move explorer, trigger chamber events (monster encounter / trap)
- **3.8** Implement `search_chamber`: Perception skill check, reveal hidden traps or treasure
- **3.9** Implement trap mechanics: saving throw to avoid, damage on failure, `disarm_trap` skill check
- **3.10** Implement `loot_treasure` and `loot_fallen`: pick up chamber treasure or fallen explorer's items, update inventory
- **3.11** Implement XP gain and level-up: check thresholds, increase max HP (roll hit die + CON), update proficiency bonus, unlock class features, add spell slots for Wizard
- **3.12** Implement boss defeat: on boss kill, increment `temples_conquered`, mark `boss_alive = false`
- **3.13** Implement `calculate_boss_probability` with the Yonder Formula (quadratic yonder + XP component)
- **3.14** Write integration tests: full explorer-mints → enters-temple → opens-exits → explores → fights → loots → levels-up → finds-boss flow

### Day 4: AI Agent & Client
- **4.1** Set up client project (TypeScript or Python)
- **4.2** Implement Torii GraphQL client: query explorer state (stats, HP, inventory, position, skills), chamber state (type, yonder, monster, exits, fallen explorers), temple state (seed, difficulty, boss status)
- **4.3** Implement Starknet transaction submission wrapper: build and sign transactions for each game action
- **4.4** Design the AI agent system prompt: D20 rules summary, available actions per context (exploring vs combat vs at entrance), narration style guidelines, examples of NL → action mapping
- **4.5** Implement action mapping layer: LLM parses natural language → structured action (enum + params), validate action is legal given current state
- **4.6** Implement narration layer: LLM reads transaction results + world state → atmospheric text describing what happened
- **4.7** Implement game loop: read state → show context → player input → AI maps action → submit tx → wait for result → AI narrates → repeat
- **4.8** Build simple chat UI (terminal CLI or minimal web interface with chat history)
- **4.9** Handle edge cases: invalid actions (AI retries with guidance), ambiguous input (AI asks for clarification), death (narrate death scene, prompt for new explorer)
- **4.10** Implement temple selection flow: list available temples, show difficulty tier, let player choose or mint new

### Day 5: Integration, Testing & Deploy
- **5.1** End-to-end playtest: mint explorer → enter temple → explore → open exits → fight → loot → level up → find boss → die or conquer
- **5.2** Test permadeath flow: verify fallen explorer body visible, loot droppable, loot pickable by others, dead NFT frozen
- **5.3** Test cross-temple flow: enter temple A → level up → exit → enter temple B → verify stats carry over
- **5.4** Multiplayer testing: two explorers in same temple, verify shared chamber state, shared monster kills, shared chamber generation
- **5.5** Test boss probability: verify Yonder Formula produces expected distribution over many runs
- **5.6** Test all three classes through full temple runs, verify class features work correctly
- **5.7** Balance tuning: adjust monster stats, XP rewards, treasure distribution, trap DCs, boss probability constants
- **5.8** Edge case testing: death at level 1 with empty inventory, chamber with many fallen explorers, dead-end chambers, exiting temple mid-combat
- **5.9** Deploy contracts to Starknet testnet (Sepolia) via `sozo migrate`
- **5.10** Configure Torii indexer on testnet, verify GraphQL queries return correct state
- **5.11** Smoke test the full flow on testnet with live VRF
- **5.12** Document setup instructions, known limitations, and tuning constants

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
