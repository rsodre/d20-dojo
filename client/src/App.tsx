import { useState } from "react";
import { Routes, Route } from "react-router-dom";
import { Flex, Grid } from "@radix-ui/themes";
import { ConnectButton } from "@/components/connect-button";
import { MintExplorerPanel } from "@/components/mint-explorer-panel";
import { MintTemplePanel } from "@/components/mint-temple-panel";
import { ExplorerList } from "@/components/explorer-list";
import { TempleList } from "@/components/temple-list";
import { PlayerTokensProvider } from "@/contexts/player-tokens-provider";
import { useGameModels } from "@/hooks/use-game-models";
import { TempleView } from "@/pages/TempleView";

function LobbyContent() {
  const [selectedTempleId, setSelectedTempleId] = useState<bigint | null>(null);

  return (
    <Flex direction="column" gap="4">
      <Grid columns={{ initial: "1", sm: "2" }} gap="4">
        <MintExplorerPanel />
        <MintTemplePanel />
      </Grid>
      <Grid columns={{ initial: "1", sm: "2" }} gap="4">
        <ExplorerList selectedTempleId={selectedTempleId} />
        <TempleList selectedTempleId={selectedTempleId} onSelectTemple={setSelectedTempleId} />
      </Grid>
    </Flex>
  );
}

/**
 * Subscribes to all game models and provides token context for all routes.
 * Mounted once when the player is connected.
 */
function ConnectedRoutes() {
  useGameModels();

  return (
    <PlayerTokensProvider>
      <Routes>
        <Route path="/" element={<LobbyContent />} />
        <Route path="/temple/:templeId" element={<TempleView />} />
      </Routes>
    </PlayerTokensProvider>
  );
}

export default function App() {
  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between px-6 py-4 border-b border-[var(--gray-6)]">
        <span className="text-xl font-bold tracking-wide text-[var(--amber-9)]">
          D20 On-Chain
        </span>
        <ConnectButton />
      </header>
      <main className="p-6">
        <ConnectedRoutes />
      </main>
    </div>
  );
}
