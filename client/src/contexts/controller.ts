import CartridgeController from "@cartridge/controller";
import { constants } from "starknet";

// Singleton — instantiated once for the lifetime of the app.
// Chain defaults to Starknet Mainnet; override via VITE_CHAIN_ID / VITE_RPC_URL.
const chainId = (import.meta.env.VITE_CHAIN_ID ??
  constants.StarknetChainId.SN_MAIN) as `0x${string}`;

const rpcUrl =
  import.meta.env.VITE_RPC_URL ??
  "https://api.cartridge.gg/x/starknet/mainnet";

const controller = new CartridgeController({
  defaultChainId: chainId,
  chains: [{ rpcUrl }],
  // colorMode: "dark",
});

export default controller;
