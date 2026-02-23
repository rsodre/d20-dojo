import { useModel, useEntityId } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type {
  CharacterStats,
  CharacterHealth,
  CharacterCombat,
  CharacterInventory,
  CharacterPosition,
  CharacterSkills,
} from "@/generated/models.gen";

export interface ExplorerModels {
  stats: CharacterStats | undefined;
  health: CharacterHealth | undefined;
  combat: CharacterCombat | undefined;
  inventory: CharacterInventory | undefined;
  position: CharacterPosition | undefined;
  skills: CharacterSkills | undefined;
}

/**
 * Reads all explorer models from the DojoStore for the given explorer token ID.
 * Requires useGameModels() to be running somewhere in the component tree.
 */
export function useExplorerModels(characterId: bigint): ExplorerModels {
  const entityId = useEntityId(characterId);
  const { model } = useDojoConfig();

  const stats = useModel(entityId, model("CharacterStats")) as CharacterStats | undefined;
  const health = useModel(entityId, model("CharacterHealth")) as CharacterHealth | undefined;
  const combat = useModel(entityId, model("CharacterCombat")) as CharacterCombat | undefined;
  const inventory = useModel(entityId, model("CharacterInventory")) as CharacterInventory | undefined;
  const position = useModel(entityId, model("CharacterPosition")) as CharacterPosition | undefined;
  const skills = useModel(entityId, model("CharacterSkills")) as CharacterSkills | undefined;

  return { stats, health, combat, inventory, position, skills };
}
