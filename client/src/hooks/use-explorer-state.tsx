import { useModel, useEntityId } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type {
  ExplorerStats,
  ExplorerHealth,
  ExplorerCombat,
  ExplorerInventory,
  ExplorerPosition,
  ExplorerSkills,
} from "@/generated/models.gen";

export interface ExplorerModels {
  stats: ExplorerStats | undefined;
  health: ExplorerHealth | undefined;
  combat: ExplorerCombat | undefined;
  inventory: ExplorerInventory | undefined;
  position: ExplorerPosition | undefined;
  skills: ExplorerSkills | undefined;
}

/**
 * Reads all explorer models from the DojoStore for the given explorer token ID.
 * Requires useGameModels() to be running somewhere in the component tree.
 */
export function useExplorerModels(explorerId: bigint): ExplorerModels {
  const entityId = useEntityId(explorerId);
  const { model } = useDojoConfig();

  const stats = useModel(entityId, model("ExplorerStats")) as ExplorerStats | undefined;
  const health = useModel(entityId, model("ExplorerHealth")) as ExplorerHealth | undefined;
  const combat = useModel(entityId, model("ExplorerCombat")) as ExplorerCombat | undefined;
  const inventory = useModel(entityId, model("ExplorerInventory")) as ExplorerInventory | undefined;
  const position = useModel(entityId, model("ExplorerPosition")) as ExplorerPosition | undefined;
  const skills = useModel(entityId, model("ExplorerSkills")) as ExplorerSkills | undefined;

  return { stats, health, combat, inventory, position, skills };
}
