import type { ReactNode } from "react";
import { type Chain } from "@starknet-react/chains";
import { StarknetConfig, jsonRpcProvider, voyager } from "@starknet-react/core";
import { useDojoConfig } from "@/contexts/dojo-config-provider";

const provider = jsonRpcProvider({ rpc: (chain: Chain) => ({ nodeUrl: chain.rpcUrls.default.http[0] }) })

export default function StarknetProvider({ children }: { children: ReactNode }) {
  const { chains, connectors } = useDojoConfig()
  return (
    <StarknetConfig
      chains={chains}
      connectors={connectors}
      explorer={voyager}
      provider={provider}
      autoConnect={true}
    >
      {children}
    </StarknetConfig>
  );
}
