import { useEffect, useState } from "react";
import { Call, CallData } from "starknet";
import { useAccount } from "@starknet-react/core";
import { useDojoConfig } from "@/contexts/dojo-config-provider";

export function useVrfCall() {
  const { address } = useAccount();
  const { profileConfig } = useDojoConfig();
  const [requestRandomCall, setRequestRandomCall] = useState<Call | undefined>();

  useEffect(() => {
    if (address) {
      setRequestRandomCall({
        contractAddress: profileConfig.vrfAddress,
        entrypoint: 'request_random',
        calldata: CallData.compile({
          caller: address,
          source: { type: 0, address },
        }),
      });
    } else {
      setRequestRandomCall(undefined);
    }
  }, [address]);

  return {
    requestRandomCall,
  };
}
