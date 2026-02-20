import { useAccount } from "@starknet-react/core";
import { Flex, Grid, Text } from "@radix-ui/themes";
import { ConnectButton } from "@/components/connect-button";
import { MintExplorerPanel } from "@/components/mint-explorer-panel";
import { MintTemplePanel } from "@/components/mint-temple-panel";
import { ExplorerList } from "@/components/explorer-list";
import { TempleList } from "@/components/temple-list";
import { PlayerTokensProvider } from "@/contexts/player-tokens-provider";

function LobbyView() {
  return (
    <PlayerTokensProvider>
      <Flex direction="column" gap="4">
        <Grid columns={{ initial: "1", sm: "2" }} gap="4">
          <MintExplorerPanel />
          <MintTemplePanel />
        </Grid>
        <Grid columns={{ initial: "1", sm: "2" }} gap="4">
          <ExplorerList />
          <TempleList />
        </Grid>
      </Flex>
    </PlayerTokensProvider>
  );
}

export default function App() {
  const { isConnected } = useAccount();

  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between px-6 py-4 border-b border-[var(--gray-6)]">
        <span className="text-xl font-bold tracking-wide text-[var(--amber-9)]">
          D20 On-Chain
        </span>
        <ConnectButton />
      </header>
      <main className="p-6">
        {isConnected ? (
          <LobbyView />
        ) : (
          <Text color="gray">Connect your wallet to start playing.</Text>
        )}
      </main>
    </div>
  );
}
