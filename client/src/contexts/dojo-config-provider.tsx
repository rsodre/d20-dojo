import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Connector } from "@starknet-react/core";
import type { ControllerOptions } from "@cartridge/controller";
import ControllerConnector from "@cartridge/connector/controller";
import { getProfileConfig, type ProfileConfig, type ProfileName } from "@/configs";
// Dojo SDK
import { createDojoConfig } from "@dojoengine/core";
import { DojoSdkProvider } from "@dojoengine/sdk/react";
import { init, SDK } from "@dojoengine/sdk";
import { setupWorld } from "@/generated/contracts.gen.ts";
import type { SchemaType } from "@/generated/models.gen.ts";

//----------------------------
// Profile config
//
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

//----------------------------
// Dojo SDK
//
const dojoConfig = createDojoConfig({
  manifest: profileConfig.manifest,
  rpcUrl: profileConfig.rpcUrl,
  toriiUrl: profileConfig.toriiUrl,
});

//----------------------------
// Provider
//
let controller: ControllerConnector | undefined = undefined;
try {
  controller = new ControllerConnector(options)
} catch (error) {
  console.error(">>> Failed to create controller:", error);
}
const state = {
  namespace: profileConfig.namespace,
  profileName,
  profileConfig,
  chains: [profileConfig.chain],
  connectors: [controller as Connector],
  model: (name: string) => (`${profileConfig.namespace}-${name}` as `d20-${string}`)
};
type DojoConfigState = typeof state;

const DojoConfigContext = createContext<DojoConfigState>(state);

export function DojoConfigProvider({ children }: { children: ReactNode }) {
  const [sdk, setSdk] = useState<SDK<SchemaType> | undefined>();
  
  useEffect(() => {
    init<SchemaType>({
      client: {
        worldAddress: profileConfig.contractAddresses.world,
        toriiUrl: profileConfig.toriiUrl,
      },
      domain: {
        name: "D20",
        version: "0.1.0",
        chainId: profileConfig.chainId,
        revision: "1",
      },
    }).then(setSdk);
  }, [])

  if (!sdk) return null;

  return (
    <DojoConfigContext.Provider value={state}>
      <DojoSdkProvider sdk={sdk as any} dojoConfig={dojoConfig} clientFn={setupWorld}>
        {children}
      </DojoSdkProvider>
    </DojoConfigContext.Provider>
  );
}

export function useDojoConfig(): DojoConfigState {
  const ctx = useContext(DojoConfigContext);
  if (!ctx) throw new Error("useDojoConfig must be used inside <DojoConfigProvider>");
  return ctx;
}
