import { useEffect, useRef, useState } from "react";
import { useDojoSDK } from "@dojoengine/sdk/react";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { bigintToAddress } from "@/utils/utils";
import type { TokenInfo } from "@/hooks/use-player-tokens";

function toTokenInfo(item: any): TokenInfo | null {
  try {
    const tokenId: string = item.token_id ?? "0x0";
    return {
      contractAddress: bigintToAddress(item.contract_address ?? "0x0"),
      tokenId,
      tokenIdNum: BigInt(tokenId),
    };
  } catch {
    return null;
  }
}

export function useAllTemples() {
  const { sdk } = useDojoSDK();
  const { profileConfig } = useDojoConfig();

  const [temples, setTemples] = useState<TokenInfo[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const balancesRef = useRef<Map<string, TokenInfo>>(new Map());

  useEffect(() => {
    if (!sdk) return;

    const templeAddr = bigintToAddress(profileConfig.contractAddresses.temple);

    const rebuildList = () => {
      const tmps = Array.from(balancesRef.current.values());
      tmps.sort((a, b) => (a.tokenIdNum < b.tokenIdNum ? -1 : 1));
      setTemples(tmps);
    };

    setIsLoading(true);
    balancesRef.current.clear();

    let cancelled = false;
    let sub: { cancel?: () => void } | undefined;

    sdk.subscribeTokenBalance({
      contractAddresses: [templeAddr],
      callback: ({ data, error }: any) => {
        if (cancelled || error || !data) return;
        // Only include tokens with positive balance
        try {
          if (BigInt(data.balance ?? "0x0") <= 0n) return;
        } catch {
          return;
        }
        const info = toTokenInfo(data);
        if (!info || info.tokenIdNum === 0n) return;
        const key = info.tokenId;
        balancesRef.current.set(key, info);
        rebuildList();
      },
    }).then(([initialData, subscription]: any) => {
      if (cancelled) {
        subscription?.cancel?.();
        return;
      }
      sub = subscription;
      const items = initialData?.items ?? (Array.isArray(initialData) ? initialData : []);
      for (const item of items) {
        try {
          if (BigInt(item.balance ?? "0x0") <= 0n) continue;
        } catch {
          continue;
        }
        const info = toTokenInfo(item);
        if (!info || info.tokenIdNum === 0n) continue;
        balancesRef.current.set(info.tokenId, info);
      }
      rebuildList();
      setIsLoading(false);
    }).catch((err: any) => {
      if (!cancelled) {
        console.error("[useAllTemples] subscription error:", err);
        setIsLoading(false);
      }
    });

    return () => {
      cancelled = true;
      sub?.cancel?.();
    };
  }, [sdk, profileConfig.contractAddresses.temple]);

  return { temples, isLoading };
}
