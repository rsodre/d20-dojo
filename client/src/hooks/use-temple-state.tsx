import { useModel, useEntityId } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type { TempleState } from "@/generated/models.gen";

export interface TempleModels {
  state: TempleState | undefined;
}


/**
 * Reads TempleState from the DojoStore for the given temple token ID.
 * Requires useGameModels() to be running somewhere in the component tree.
 */
export function useTempleModels(templeId: bigint): TempleModels | undefined {
  const entityId = useEntityId(templeId);
  const { model } = useDojoConfig();
  
  const state = useModel(entityId, model("TempleState")) as TempleState | undefined;

  return {
    state
  };
}
