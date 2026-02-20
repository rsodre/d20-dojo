import { createContext, useContext, type ReactNode } from "react";
import { usePlayerTokens, type TokenInfo } from "@/hooks/use-player-tokens";

export type { TokenInfo };

interface PlayerTokensState {
  explorers: TokenInfo[];
  temples: TokenInfo[];
  isLoading: boolean;
}

const PlayerTokensContext = createContext<PlayerTokensState>({
  explorers: [],
  temples: [],
  isLoading: false,
});

export function PlayerTokensProvider({ children }: { children: ReactNode }) {
  const tokens = usePlayerTokens();
  return (
    <PlayerTokensContext.Provider value={tokens}>
      {children}
    </PlayerTokensContext.Provider>
  );
}

export function usePlayerTokensContext(): PlayerTokensState {
  return useContext(PlayerTokensContext);
}
