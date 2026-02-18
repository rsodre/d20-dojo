# D20 On-Chain: Agent Guide

This document is a high-level entry point for autonomous agents (LLMs or bots) interacting with the D20 On-Chain world.

## Developer Guidance

If you are an agent tasked with **developing or modifying** the game's contracts and systems, please refer to [CLAUDE.md](CLAUDE.md) for implementation details, build commands, and project structure guidelines.

## High-Level Flow

1. **Character Creation**: Mint an explorer and assign stats strategically.
2. **Preparation**: Choose or mint a temple, then rest to ensure full health.
3. **Exploration**: Enter the temple, open exits, and move through chambers. 
4. **Combat**: Survive monster encounters using class features and items.
5. **Goal**: Locate and defeat the temple boss to conquer the temple.

## Death is Permanent

Caution: Once an explorer dies, the character cannot be restored. Monitor your HP via the `ExplorerHealth` model and exit the temple or rest if you are in danger.

## Key Resources

- **[GAMEPLAY.md](GAMEPLAY.md)**: **REQUIRED READING.** Contains all contract methods, technical details on VRF, and procedural mechanics.
- **[SPEC.md](SPEC.md)**: Full project specification, including D20 math and model definitions.
