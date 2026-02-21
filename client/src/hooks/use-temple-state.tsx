import { useModel, useEntityId } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type { DungeonState } from "@/generated/models.gen";

export interface TempleModels {
  state: DungeonState | undefined;
}


/**
 * Reads DungeonState from the DojoStore for the given temple token ID.
 * Requires useGameModels() to be running somewhere in the component tree.
 */
export function useTempleModels(templeId: bigint): TempleModels | undefined {
  const entityId = useEntityId(templeId);
  const { model } = useDojoConfig();
  
  const state = useModel(entityId, model("DungeonState")) as DungeonState | undefined;

  return {
    state
  };
}
