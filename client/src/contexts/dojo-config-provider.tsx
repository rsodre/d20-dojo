import { createContext, useContext, type ReactNode } from "react";
import type { Connector } from "@starknet-react/core";
import type { Chain } from "@starknet-react/chains";
import type { ControllerOptions } from "@cartridge/controller";
import ControllerConnector from "@cartridge/connector/controller";
import { getProfileConfig, type ProfileConfig, type ProfileName } from "@/configs";
// Dojo SDK
import { createDojoConfig } from "@dojoengine/core";
import { DojoSdkProvider } from "@dojoengine/sdk/react";
import { init, SDK } from "@dojoengine/sdk";
import { setupWorld } from "@/generated/contracts.gen.ts";
import type { SchemaType } from "@/generated/models.gen.ts";
import { sepolia } from "@starknet-react/chains";

const profileName: ProfileName = import.meta.env.VITE_PROFILE as ProfileName;
const profileConfig: ProfileConfig = getProfileConfig(profileName);
console.log(`ProfileConfig [${profileName}]:`, profileConfig)

const options: ControllerOptions = {
  defaultChainId: profileConfig.chainId,
  chains: [{ rpcUrl: profileConfig.rpcUrl }],
  // policies: buildPolicies(),
  // preset: "cartridge",
  namespace: profileConfig.namespace,
  slot: profileConfig.slotName,
  tokens: {
    //@ts-ignore
    erc721: [profileConfig.contractAddresses.explorer, profileConfig.contractAddresses.temple],
  },
};

const state = {
  namespace: profileConfig.namespace,
  profileName,
  profileConfig,
  chains: [profileConfig.chain],
  connectors: [new ControllerConnector(options) as Connector],
};

type DojoConfigState = typeof state;

const DojoConfigContext = createContext<DojoConfigState>(state);

export function DojoConfigProvider({ children }: { children: ReactNode }) {
  return (
    <DojoConfigContext.Provider value={state}>
      {children}
    </DojoConfigContext.Provider>
  );
}

export function useDojoConfig(): DojoConfigState {
  const ctx = useContext(DojoConfigContext);
  if (!ctx) throw new Error("useDojoConfig must be used inside <DojoConfigProvider>");
  return ctx;
}
