import { CairoCustomEnum } from "starknet";
import type { ChamberExit, FallenAdventurer } from "@/generated/models.gen";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface Action {
  id: string;
  label: string;
  contract: string;   // contract address
  entrypoint: string;
  calldata: unknown[]; // pre-compilation args passed to CallData.compile(entrypoint, calldata)
  needsVrf: boolean;
  color: 'red' | 'green' | 'blue' | 'purple' | 'orange' | 'yellow' | undefined;
}

export interface GameActionContext {
  explorerId: bigint;
  // Explorer state
  explorerClass: string; // "Fighter" | "Rogue" | "Wizard"
  level: number;
  isDead: boolean;
  inCombat: boolean;
  templeId: bigint;
  chamberId: bigint;
  potions: number;
  // AdventurerCombat
  secondWindUsed: boolean;
  spellSlots1: number;
  spellSlots2: number;
  spellSlots3: number;
  // Chamber
  chamberType: string;    // "Entrance" | "Empty" | "Monster" | "Treasure" | "Trap" | "Boss" | "None"
  exitCount: number;
  treasureLooted: boolean;
  trapDisarmed: boolean;
  // Relations
  exits: ChamberExit[];
  fallenExplorers: FallenAdventurer[];
  // Contract addresses
  contracts: {
    temple: string;
    combat: string;
  };
}

// ─── Helper ───────────────────────────────────────────────────────────────────

function enumVariant(value: unknown): string {
  if (!value) return "None";
  if (typeof value === "object" && "activeVariant" in (value as object)) {
    return (value as { activeVariant: () => string }).activeVariant();
  }
  return String(value);
}

// ─── Pure action generator ────────────────────────────────────────────────────

export function getAvailableActions(ctx: GameActionContext): Action[] {
  if (ctx.isDead || ctx.templeId === 0n) return [];

  const actions: Action[] = [];
  const { explorerId, contracts } = ctx;

  if (ctx.inCombat) {
    // ── Combat ───────────────────────────────────────────────────────────────

    actions.push({
      id: "attack",
      label: "⚔️ Attack",
      contract: contracts.combat,
      entrypoint: "attack",
      calldata: [explorerId],
      needsVrf: true,
      color: 'green',
    });

    if (ctx.explorerClass === "Fighter" && !ctx.secondWindUsed) {
      actions.push({
        id: "second_wind",
        label: "💚 Second Wind",
        contract: contracts.combat,
        entrypoint: "second_wind",
        calldata: [explorerId],
        needsVrf: true,
        color: 'green',
      });
    }

    if (ctx.explorerClass === "Rogue" && ctx.level >= 2) {
      actions.push({
        id: "cunning_action",
        label: "💨 Cunning Action (Disengage)",
        contract: contracts.combat,
        entrypoint: "cunning_action",
        calldata: [explorerId],
        needsVrf: false,
        color: 'green',
      });
    }

    if (ctx.explorerClass === "Wizard") {
      // Cantrip — always available
      actions.push({
        id: "cast_firebolt",
        label: "🔥 Fire Bolt (Cantrip)",
        contract: contracts.combat,
        entrypoint: "cast_spell",
        calldata: [explorerId, new CairoCustomEnum({ FireBolt: {} })],
        needsVrf: true,
        color: 'purple',
      });

      if (ctx.spellSlots1 > 0) {
        actions.push({
          id: "cast_magic_missile",
          label: `🎯 Magic Missile (Lv1, ${ctx.spellSlots1} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ MagicMissile: {} })],
          needsVrf: true,
          color: 'purple',
        });
        actions.push({
          id: "cast_sleep",
          label: `😴 Sleep (Lv1, ${ctx.spellSlots1} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ Sleep: {} })],
          needsVrf: true,
          color: 'purple',
        });
        actions.push({
          id: "cast_shield",
          label: `🛡️ Shield (Lv1 reaction, ${ctx.spellSlots1} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ Shield: {} })],
          needsVrf: true,
          color: 'purple',
        });
      }

      if (ctx.spellSlots2 > 0) {
        actions.push({
          id: "cast_scorching_ray",
          label: `☀️ Scorching Ray (Lv2, ${ctx.spellSlots2} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ ScorchingRay: {} })],
          needsVrf: true,
          color: 'purple',
        });
        actions.push({
          id: "cast_misty_step",
          label: `🌫️ Misty Step (Lv2 disengage, ${ctx.spellSlots2} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ MistyStep: {} })],
          needsVrf: true,
          color: 'purple',
        });
      }

      if (ctx.spellSlots3 > 0) {
        actions.push({
          id: "cast_fireball",
          label: `💥 Fireball (Lv3, ${ctx.spellSlots3} left)`,
          contract: contracts.combat,
          entrypoint: "cast_spell",
          calldata: [explorerId, new CairoCustomEnum({ Fireball: {} })],
          needsVrf: true,
          color: 'purple',
        });
      }
    }

    if (ctx.potions > 0) {
      actions.push({
        id: "use_potion",
        label: `🧪 Use Health Potion (${ctx.potions})`,
        contract: contracts.combat,
        entrypoint: "use_item",
        calldata: [explorerId, new CairoCustomEnum({ HealthPotion: {} })],
        needsVrf: true,
        color: 'purple',
      });
    }

    actions.push({
      id: "flee",
      label: "🏃 Flee",
      contract: contracts.combat,
      entrypoint: "flee",
      calldata: [explorerId],
      needsVrf: true,
      color: 'green',
    });

  } else {
    // ── Exploring ─────────────────────────────────────────────────────────────

    for (let i = 0; i < ctx.exitCount; i++) {
      const exit = ctx.exits.find((e) => Number(BigInt(e.exit_index)) === i);
      const isDiscovered = exit?.is_discovered ?? false;

      if (!isDiscovered) {
        actions.push({
          id: `open_exit_${i}`,
          label: `🚪 Exit ${i + 1}: Open`,
          contract: contracts.temple,
          entrypoint: "open_exit",
          calldata: [explorerId, i],
          needsVrf: true,
          color: 'orange',
        });
      } else {
        const toChamber = exit ? Number(BigInt(exit.to_chamber_id)) : "?";
        actions.push({
          id: `move_${i}`,
          label: `➡️ Exit ${i + 1}: Enter Chamber #${toChamber}`,
          contract: contracts.temple,
          entrypoint: "move_to_chamber",
          calldata: [explorerId, i],
          needsVrf: true,
          color: 'yellow',
        });
      }
    }

    if (
      (ctx.chamberType === "Treasure" || ctx.chamberType === "Empty") &&
      !ctx.treasureLooted
    ) {
      actions.push({
        id: "loot_treasure",
        label: "💰 Loot Treasure",
        contract: contracts.temple,
        entrypoint: "loot_treasure",
        calldata: [explorerId],
        needsVrf: true,
        color: 'green',
      });
    }

    if (ctx.chamberType === "Trap" && !ctx.trapDisarmed) {
      actions.push({
        id: "disarm_trap",
        label: "⚙️ Disarm Trap",
        contract: contracts.temple,
        entrypoint: "disarm_trap",
        calldata: [explorerId],
        needsVrf: true,
        color: 'green',
      });
    }

    for (const fallen of ctx.fallenExplorers) {
      if (!fallen.is_looted) {
        const idx = Number(BigInt(fallen.fallen_index));
        actions.push({
          id: `loot_fallen_${idx}`,
          label: `🩸 Loot Fallen Explorer #${idx + 1}`,
          contract: contracts.temple,
          entrypoint: "loot_fallen",
          calldata: [explorerId, idx],
          needsVrf: false,
          color: 'green',
        });
      }
    }

    actions.push({
      id: "exit_temple",
      label: "🚶 Exit Temple",
      contract: contracts.temple,
      entrypoint: "exit_temple",
      calldata: [explorerId],
      needsVrf: false,
      color: 'red',
    });
  }

  return actions;
}

// ─── Re-export helper so callers can read enum variants ───────────────────────
export { enumVariant };
