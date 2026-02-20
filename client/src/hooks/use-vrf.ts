import { useCallback } from "react";
import { BigNumberish, CallData } from "starknet";
import { useAccount } from "@starknet-react/core";
import { useDojoConfig } from "@/contexts/dojo-config-provider";

export function useVrfCall() {
  const { address } = useAccount();
  const { profileConfig } = useDojoConfig();

  const requestRandomCall = useCallback((caller_contract_address: BigNumberish) => ({
    contractAddress: profileConfig.vrfAddress,
    entrypoint: 'request_random',
    calldata: CallData.compile({
      caller: caller_contract_address,
      source: { type: 0, address },
    }),
  }), [address, profileConfig.vrfAddress])

  return {
    requestRandomCall,
  };
}
