# D20 On-Chain: Gameplay Guide

This document provides a detailed technical reference for the game's systems and public interfaces. It is intended for both human players and autonomous agents who need to understand the underlying contract methods.

## System Overview

The game logic is divided into three main contracts. Each contract exposes a public interface for player interactions.

> [!IMPORTANT]
> **VRF Multicall Requirement**: If a function listed below is marked as "(Consumes VRF)", it must be executed as part of a **multicall**. The first transaction in the multicall must be a call to `request_random` on the VRF contract (`0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f`).
>
> Example multicall structure:
> ```javascript
> [
>   {
>     contractAddress: '0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f',
>     entrypoint: 'request_random',
>     calldata: CallData.compile({
>       caller: contract_address,
>       source: { type: 0, address: nonceAddress },
>     }),
>   },
>   {
>     contractAddress: GAME_SYSTEM_ADDRESS,
>     entrypoint: 'attack', // or any other VRF action
>     calldata: CallData.compile({
>       explorer_id: '1',
>     }),
>   }
> ]
> ```

---

## 1. Explorer System

Managed by the `explorer_token` contract. This system handles character creation and management.

**Source Interface**: [IExplorerTokenPublic](packages/contracts/src/systems/explorer_token.cairo#L68)

### `mint_explorer`
Mint a new Explorer NFT.
- **VRF**: Consumes VRF — must be preceded by `request_random` in a multicall.
- **Parameters**:
  - `class`: `Fighter`, `Rogue`, or `Wizard`
- **Returns**: The new explorer's token ID (`u128`).
- **Randomization**: Stats (`[STR, DEX, CON, INT, WIS, CHA]`) are randomly assigned from the standard array `[15, 14, 13, 12, 10, 8]` using VRF, with a class-biased shuffle (high stats tend toward primary abilities). Skills and expertise are also randomly selected from the valid options for the chosen class.
- **Class stat bias**:
  - Fighter: prefers STR → CON → DEX
  - Rogue: prefers DEX → CON → CHA
  - Wizard: prefers INT → WIS → DEX

### `rest`
Restore HP to maximum and reset class resources.
- **Effect**: Sets `current_hp` to `max_hp`, resets spell slots, and resets used features like `second_wind` or `action_surge`.

---

## 2. Temple System

Managed by the `temple_token` contract. This system handles the procedural generation of temples and exploration.

**Source Interface**: [ITempleTokenPublic](packages/contracts/src/systems/temple_token.cairo#L87)

### `mint_temple`
Mint a new Temple NFT with a specific difficulty.
- **Parameters**:
  - `difficulty`: Tier (1 = easy, higher = harder).

### `enter_temple`
Place an explorer at the entrance (Chamber 1) of a temple.
- **Requirement**: Explorer must be owned by the caller and not in combat.

### `exit_temple`
Remove an explorer from their current temple.
- **Requirement**: Cannot exit during combat.

### `open_exit`
Discover a new chamber from an unexplored exit in the current chamber.
- **VRF**: Consumes VRF to generate the new chamber's layout, type, and contents.

### `move_to_chamber`
Move the explorer through a previously discovered exit.
- **Mechanic**: May trigger combat (if a monster is present) or fire a trap.

### `disarm_trap`
Attempt to disable a trap in the current chamber.
- **VRF**: Consumes VRF for the check and potential damage if it fails and triggers the trap.

### `loot_treasure`
Search for gold and potions in `Empty` or `Treasure` chambers.
- **VRF**: Consumes VRF for the Perception check.

### `loot_fallen`
Pick up items dropped by a dead explorer in the current chamber.

---

## 3. Combat System

Managed by the `combat_system` contract. This system handles all turn-based interactions with monsters.

**Source Interface**: [ICombatSystem](packages/contracts/src/systems/combat_system.cairo#L7)

### `attack`
Perform a standard weapon attack against the monster in the current chamber.
- **Mechanic**: Rolls `d20 + modifiers` vs. monster AC. Consumes VRF for the attack, damage, and the monster's counter-attack.

### `cast_spell`
Wizard-only action to cast a cantrip or leveled spell.
- **Mechanic**: Consumes a spell slot if leveled. Consumes VRF for spell effects and monster counter-attack.

### `use_item`
Use a consumable, such as a Health Potion (heals `2d4+2`).
- **VRF**: Consumes VRF for the healing roll.

### `flee`
Attempt to escape combat and move back to the previous chamber.
- **VRF**: Consumes VRF for the contested DEX check.

### `second_wind`
Fighter-only feature: heal `1d10 + level` once per rest.
- **VRF**: Consumes VRF for the healing roll.

### `cunning_action`
Rogue-only feature: disengage or hide without triggering a monster counter-attack.

---

## Technical Details

### Randomness (Cartridge VRF)
All actions involving dice rolls require Cartridge VRF. These transactions must be submitted via a provider or paymaster that handles the VRF Request/Consume flow (like the Cartridge Controller).

### Death is Permanent
When `ExplorerHealth.is_dead` becomes true, the NFT is frozen. The character's inventory is dropped in the chamber where they fell, and can be retrieved by other explorers via `loot_fallen`.
