import { useDojoSDK } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import type { Chamber, ChamberExit, FallenExplorer, MonsterInstance } from "@/generated/models.gen";

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

/**
 * Returns ChamberExit models for a specific chamber, sorted by exit_index.
 * Requires useGameModels() to be running.
 */
export function useChamberExits(templeId: bigint, chamberId: bigint): ChamberExit[] {
  const { useDojoStore } = useDojoSDK();
  const { namespace } = useDojoConfig();

  return useDojoStore((state) => {
    const entities = state.getEntitiesByModel(namespace, "ChamberExit");
    return entities
      .map((e: any) => e.models?.[namespace]?.["ChamberExit"] as ChamberExit | undefined)
      .filter(
        (c): c is ChamberExit =>
          c != null &&
          BigInt(c.temple_id) === templeId &&
          BigInt(c.from_chamber_id) === chamberId,
      )
      .sort((a, b) => Number(BigInt(a.exit_index) - BigInt(b.exit_index)));
  });
}

/**
 * Returns FallenExplorer models for a specific chamber, sorted by fallen_index.
 * Requires useGameModels() to be running.
 */
export function useFallenExplorers(templeId: bigint, chamberId: bigint): FallenExplorer[] {
  const { useDojoStore } = useDojoSDK();
  const { namespace } = useDojoConfig();

  return useDojoStore((state) => {
    const entities = state.getEntitiesByModel(namespace, "FallenExplorer");
    return entities
      .map((e: any) => e.models?.[namespace]?.["FallenExplorer"] as FallenExplorer | undefined)
      .filter(
        (f): f is FallenExplorer =>
          f != null &&
          BigInt(f.temple_id) === templeId &&
          BigInt(f.chamber_id) === chamberId,
      )
      .sort((a, b) => Number(BigInt(a.fallen_index) - BigInt(b.fallen_index)));
  });
}
