import { useEntityQuery } from "@dojoengine/sdk/react";
import { ToriiQueryBuilder } from "@dojoengine/sdk";
import type { SchemaType } from "@/generated/models.gen";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useMemo } from "react";

/**
 * Subscribes to all game model types via Torii gRPC and populates the DojoStore.
 * Call this hook once in a top-level component (e.g. LobbyView) when the player is connected.
 * Read individual models with useExplorerModels() / useTempleModels().
 */
export function useGameModels() {
  const { model } = useDojoConfig();

  const models = useMemo(() => ([
    model("AdventurerStats"),
    model("AdventurerHealth"),
    model("AdventurerCombat"),
    model("AdventurerInventory"),
    model("AdventurerPosition"),
    model("AdventurerSkills"),
    model("DungeonState"),
    model("Chamber"),
    model("ChamberFallenCount"),
    model("MonsterInstance"),
    model("ChamberExit"),
    model("FallenAdventurer"),
    model("AdventurerDungeonProgress"),

  ]), [model])

  // Explorer models — single key: adventurer_id
  useEntityQuery(
    new ToriiQueryBuilder<SchemaType>()
      // .withClause(
      //   KeysClause<SchemaType>(
      //     models,
      //     [undefined],
      //     "VariableLen"
      //   ).build()
      // )
      .withEntityModels(models)
      .includeHashedKeys()
      .withLimit(1000)
  );
}
