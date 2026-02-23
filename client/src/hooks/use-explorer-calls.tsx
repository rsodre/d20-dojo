import { useMemo } from "react";
import { useMutation } from "@tanstack/react-query";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useAccount } from "@starknet-react/core";
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

  const mint_explorer = useMutation({
    mutationFn: (account?.address && requestRandomCall) ?
      (selectedClass: string) => {
        const explorerClassEnum = new CairoCustomEnum({ [selectedClass]: {} });
        const entrypoint = "mint_explorer";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall(contractAddress),
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerClassEnum]),
          },
        ];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`explorer.mint_explorer() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`explorer.mint_explorer() error:`, error);
    },
  });


  // const mint_explorer = useCallback(
  //   async (selectedClass: string) => {
  //     try {
  //       return result.transaction_hash;
  //     } catch (e) {
  //       console.log(`explorer.mint_explorer() error:`, e);
  //       return null;
  //     }
  //   },
  //   [account, contractAddress, callData, requestRandomCall],
  // );

  const rest = useMutation({
    mutationFn: account?.address ?
      (characterId: bigint) => {
        const entrypoint = "rest";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [characterId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`explorer.rest() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`explorer.rest() error:`, error);
    },
  });

  return {
    mint_explorer,
    rest,
  };
};