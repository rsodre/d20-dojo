import { useModel, useEntityId } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type {
  AdventurerStats,
  AdventurerHealth,
  AdventurerCombat,
  AdventurerInventory,
  AdventurerPosition,
  AdventurerSkills,
} from "@/generated/models.gen";

export interface ExplorerModels {
  stats: AdventurerStats | undefined;
  health: AdventurerHealth | undefined;
  combat: AdventurerCombat | undefined;
  inventory: AdventurerInventory | undefined;
  position: AdventurerPosition | undefined;
  skills: AdventurerSkills | undefined;
}

/**
 * Reads all explorer models from the DojoStore for the given explorer token ID.
 * Requires useGameModels() to be running somewhere in the component tree.
 */
export function useExplorerModels(explorerId: bigint): ExplorerModels {
  const entityId = useEntityId(explorerId);
  const { model } = useDojoConfig();

  const stats = useModel(entityId, model("AdventurerStats")) as AdventurerStats | undefined;
  const health = useModel(entityId, model("AdventurerHealth")) as AdventurerHealth | undefined;
  const combat = useModel(entityId, model("AdventurerCombat")) as AdventurerCombat | undefined;
  const inventory = useModel(entityId, model("AdventurerInventory")) as AdventurerInventory | undefined;
  const position = useModel(entityId, model("AdventurerPosition")) as AdventurerPosition | undefined;
  const skills = useModel(entityId, model("AdventurerSkills")) as AdventurerSkills | undefined;

  return { stats, health, combat, inventory, position, skills };
}
