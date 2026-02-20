import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useAccount } from "@starknet-react/core";
import { useCallback, useMemo } from "react";
import { CairoCustomEnum, Call, CallData } from "starknet";
import { useVrfCall } from "@/hooks/use-vrf";

export const useExplorerCalls = () => {
  const { account } = useAccount();
  const { requestRandomCall } = useVrfCall();
  const { profileConfig } = useDojoConfig();
  const contractAddress = profileConfig.contractAddresses.explorer;

  const callData = useMemo(() => 
    new CallData(profileConfig.manifest.abis)
  , [profileConfig]);

  const mint_explorer = useCallback(
    async (selectedClass: string) => {
      try {
        if (!account?.address || !requestRandomCall) return null;
        const explorerClassEnum = new CairoCustomEnum({ [selectedClass]: {} });
        const entrypoint = "mint_explorer";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall,
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerClassEnum]),
          },
        ];
        const result = await account.execute(calls);
        return result.transaction_hash;
      } catch (e) {
        console.log(`explorer.mint_explorer() error:`, e);
        return null;
      }
    },
    [account, contractAddress, callData, requestRandomCall],
  );

  return {
    mint_explorer,
  };
};