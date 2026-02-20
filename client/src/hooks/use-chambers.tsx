import { useDojoSDK } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type { Chamber, MonsterInstance } from "@/generated/models.gen";

/**
 * Returns all Chamber models for the given temple from the DojoStore.
 * Sorted by chamber_id ascending.
 * Requires useGameModels() to be running.
 */
export function useChambers(templeId: bigint): Chamber[] {
  const { useDojoStore } = useDojoSDK();
  const { namespace } = useDojoConfig();

  return useDojoStore((state) => {
    const entities = state.getEntitiesByModel(namespace, "Chamber");
    return entities
      .map((e: any) => e.models?.[namespace]?.["Chamber"] as Chamber | undefined)
      .filter((c): c is Chamber => c != null && BigInt(c.temple_id) === templeId)
      .sort((a, b) => Number(BigInt(a.chamber_id) - BigInt(b.chamber_id)));
  });
}

/**
 * Returns all MonsterInstance models for the given temple from the DojoStore.
 * Requires useGameModels() to be running.
 */
export function useMonsterInstances(templeId: bigint): MonsterInstance[] {
  const { useDojoStore } = useDojoSDK();
  const { namespace } = useDojoConfig();

  return useDojoStore((state) => {
    const entities = state.getEntitiesByModel(namespace, "MonsterInstance");
    return entities
      .map((e: any) => e.models?.[namespace]?.["MonsterInstance"] as MonsterInstance | undefined)
      .filter((m): m is MonsterInstance => m != null && BigInt(m.temple_id) === templeId);
  });
}
