import { useEffect, useRef, useState } from "react";
import { useDojoSDK } from "@dojoengine/sdk/react";
import { useAccount } from "@starknet-react/core";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { bigintToAddress } from "@/utils/utils";

export interface TokenInfo {
  contractAddress: string;
  tokenId: string;        // hex u256 string
  tokenIdNum: bigint;     // for display/sorting
}

interface RawBalance {
  contractAddress: string;
  tokenId: string;
  balance: string;
}

function parseBalance(item: any): RawBalance {
  return {
    contractAddress: bigintToAddress(item.contract_address ?? "0x0"),
    tokenId: item.token_id ?? "0x0",
    balance: item.balance ?? "0x0",
  };
}

function toTokenInfo(raw: RawBalance): TokenInfo {
  return {
    contractAddress: raw.contractAddress,
    tokenId: raw.tokenId,
    tokenIdNum: (() => { try { return BigInt(raw.tokenId); } catch { return 0n; } })(),
  };
}

export function usePlayerTokens() {
  const { sdk } = useDojoSDK();
  const { account } = useAccount();
  const { profileConfig } = useDojoConfig();

  const [explorers, setExplorers] = useState<TokenInfo[]>([]);
  const [temples, setTemples] = useState<TokenInfo[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const balancesRef = useRef<Map<string, RawBalance>>(new Map());

  useEffect(() => {
    if (!sdk || !account?.address) {
      setExplorers([]);
      setTemples([]);
      balancesRef.current.clear();
      return;
    }

    const explorerAddr = bigintToAddress(profileConfig.contractAddresses.explorer);
    const templeAddr = bigintToAddress(profileConfig.contractAddresses.temple);

    const rebuildLists = () => {
      const exps: TokenInfo[] = [];
      const tmps: TokenInfo[] = [];
      for (const raw of balancesRef.current.values()) {
        try {
          if (BigInt(raw.balance) <= 0n) continue;
        } catch {
          continue;
        }
        const info = toTokenInfo(raw);
        if (info.tokenIdNum === 0n) continue;
        if (raw.contractAddress === explorerAddr) exps.push(info);
        else if (raw.contractAddress === templeAddr) tmps.push(info);
      }
      exps.sort((a, b) => (a.tokenIdNum < b.tokenIdNum ? -1 : 1));
      tmps.sort((a, b) => (a.tokenIdNum < b.tokenIdNum ? -1 : 1));
      setExplorers(exps);
      setTemples(tmps);
    };

    setIsLoading(true);
    balancesRef.current.clear();

    let cancelled = false;
    let sub: { cancel?: () => void; free?: () => void } | undefined;

    sdk.subscribeTokenBalance({
      accountAddresses: [bigintToAddress(account.address)],
      contractAddresses: [explorerAddr, templeAddr],
      callback: ({ data, error }: any) => {
        if (cancelled || error || !data) return;
        const raw = parseBalance(data);
        const key = `${raw.contractAddress}:${raw.tokenId}`;
        balancesRef.current.set(key, raw);
        rebuildLists();
      },
    }).then(([initialData, subscription]: any) => {
      if (cancelled) {
        subscription?.cancel?.();
        return;
      }
      sub = subscription;
      // Process initial snapshot
      const items = initialData?.items ?? (Array.isArray(initialData) ? initialData : []);
      for (const item of items) {
        const raw = parseBalance(item);
        const key = `${raw.contractAddress}:${raw.tokenId}`;
        balancesRef.current.set(key, raw);
      }
      rebuildLists();
      setIsLoading(false);
    }).catch((err: any) => {
      if (!cancelled) {
        console.error("[usePlayerTokens] subscription error:", err);
        setIsLoading(false);
      }
    });

    return () => {
      cancelled = true;
      sub?.cancel?.();
    };
  }, [sdk, account?.address, profileConfig.contractAddresses.explorer, profileConfig.contractAddresses.temple]);

  return { explorers, temples, isLoading };
}
