import { type Chain, sepolia } from "@starknet-react/chains";
import { addAddressPadding } from "starknet";
import { bigintToHex, stringToFelt } from "@/utils/utils";
import manifest_dev from "@/generated/manifest_dev.json";
import manifest_katana from "@/generated/manifest_katana.json";
// import manifest_sepolia from "@/generated/manifest_sepolia.json";
const manifest_sepolia = manifest_dev;

//----------------------------------------------------
// Profiles 
//

export type ProfileName = "dev" | "katana" | "sepolia";

export type ProfileConfig = {
  profileName: ProfileName;
  namespace: string;
  manifest: any;
  chainName: string;
  rpcUrl: string;
  toriiUrl: string;
  slotName: string | undefined;
  vrfAddress: string;
  // derived in getProfileConfig()
  chainId: `0x${string}`; // chain name in hex used by starknet
  chain: Chain,
  contractAddresses: {
    world: string;
    explorer: string;
    temple: string;
    combat: string;
  }
};

const NAMESPACE = "d20_0_1";

// Cartridge VRF contract address (same for all environments)
const CARTRIDGE_VRF_ADDRESS = "0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f";

const profileConfigs: Record<ProfileName, ProfileConfig> = {
  dev: {
    profileName: "dev",
    namespace: NAMESPACE,
    manifest: manifest_dev,
    chainName: "KATANA_LOCAL",
    rpcUrl: "http://localhost:5050",
    toriiUrl: "http://localhost:8080",
    slotName: undefined,
    vrfAddress: CARTRIDGE_VRF_ADDRESS,
    // derived
    chainId: undefined as any,
    chain: undefined as any,
    contractAddresses: {} as any,
  },
  katana: {
    profileName: "katana",
    namespace: NAMESPACE,
    manifest: manifest_katana,
    chainName: "WP_D20_KATANA",
    rpcUrl: "https://api.cartridge.gg/x/d20-katana/katana",
    toriiUrl: "https://api.cartridge.gg/x/d20-katana/torii",
    slotName: "d20-katana",
    vrfAddress: CARTRIDGE_VRF_ADDRESS,
    // derived
    chainId: undefined as any,
    chain: undefined as any,
    contractAddresses: {} as any,
  },
  sepolia: {
    profileName: "sepolia",
    namespace: NAMESPACE,
    manifest: manifest_sepolia,
    chainName: "SN_SEPOLIA",
    rpcUrl: "https://api.cartridge.gg/x/starknet/sepolia/rpc/v0_9",
    toriiUrl: "https://api.cartridge.gg/x/d20-sepolia/torii",
    slotName: "d20-sepolia",
    vrfAddress: CARTRIDGE_VRF_ADDRESS,
    // derived
    chainId: undefined as any,
    chain: sepolia,
    contractAddresses: {} as any,
  },
}

export const getProfileConfig = (profileName: ProfileName): ProfileConfig => {
  const result: ProfileConfig = profileConfigs[profileName];
  if (!result) {
    throw new Error(`Profile config for [${profileName}] not found`);
  }
  result.chainId = bigintToHex(stringToFelt(result.chainName));
  result.contractAddresses = {
    world: addAddressPadding(result.manifest.world.address),
    explorer: addAddressPadding(result.manifest.contracts.find((c: any) => c.tag === `${result.namespace}-explorer_token`)?.address ?? '0x0'),
    temple: addAddressPadding(result.manifest.contracts.find((c: any) => c.tag === `${result.namespace}-temple_token`)?.address ?? '0x0'),
    combat: addAddressPadding(result.manifest.contracts.find((c: any) => c.tag === `${result.namespace}-combat_system`)?.address ?? '0x0'),
  };
  if (!result.chain) {
    result.chain = {
      id: BigInt(result.chainId),
      name: result.profileName,
      network: 'katana',
      testnet: true,
      nativeCurrency: { ...sepolia.nativeCurrency },
      rpcUrls: {
        default: { http: [] },
        public: { http: [] },
      },
      paymasterRpcUrls: {
        default: { http: [result.rpcUrl] },
        public: { http: [result.rpcUrl] },
        avnu: { http: [result.rpcUrl] },
      },
      explorers: { ...sepolia.explorers },
    } as Chain;
  }
  return result;
}
