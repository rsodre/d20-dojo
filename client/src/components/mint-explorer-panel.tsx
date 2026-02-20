import { useState } from "react";
import { Button, Card, Flex, Heading, Text } from "@radix-ui/themes";
import { useAccount } from "@starknet-react/core";
import { useExplorerCalls } from "@/hooks/use-explorer-calls";

type ExplorerClass = "Fighter" | "Rogue" | "Wizard";

const CLASS_INFO: Record<ExplorerClass, { label: string; desc: string; emoji: string }> = {
  Fighter: { label: "Fighter", desc: "d10 HP · Longsword · Chain Mail AC 16", emoji: "⚔️" },
  Rogue:   { label: "Rogue",   desc: "d8 HP · Dagger + Shortbow · Leather AC",  emoji: "🗡️" },
  Wizard:  { label: "Wizard",  desc: "d6 HP · Staff · Spells · AC 10+DEX",      emoji: "🧙" },
};

export function MintExplorerPanel() {
  const { isConnected } = useAccount();
  const { mint_explorer } = useExplorerCalls();

  const [selectedClass, setSelectedClass] = useState<ExplorerClass | null>(null);
  const [isPending, setIsPending] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleMint = async () => {
    if (!isConnected || !selectedClass) return;

    setIsPending(true);
    setTxHash(null);
    setError(null);

    try {
      const tx = await mint_explorer(selectedClass);
      setTxHash(tx);
    } catch (err: any) {
      setError(err?.message ?? String(err));
    } finally {
      setIsPending(false);
    }
  };

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">Mint Explorer</Heading>
        <Text size="2" color="gray">Choose your class — stats are randomized by VRF on-chain.</Text>

        <Flex gap="2" wrap="wrap">
          {(Object.keys(CLASS_INFO) as ExplorerClass[]).map((cls) => {
            const { label, desc, emoji } = CLASS_INFO[cls];
            const isSelected = selectedClass === cls;
            return (
              <Card
                key={cls}
                onClick={() => setSelectedClass(cls)}
                style={{
                  cursor: "pointer",
                  flex: "1 1 140px",
                  border: isSelected ? "2px solid var(--amber-9)" : "2px solid transparent",
                  background: isSelected ? "var(--amber-2)" : undefined,
                }}
              >
                <Flex direction="column" gap="1" align="center">
                  <Text size="5">{emoji}</Text>
                  <Text weight="bold" size="2">{label}</Text>
                  <Text size="1" color="gray" align="center">{desc}</Text>
                </Flex>
              </Card>
            );
          })}
        </Flex>

        <Button
          onClick={handleMint}
          disabled={!isConnected || !selectedClass || isPending}
          loading={isPending}
          color="amber"
        >
          {selectedClass ? `Mint ${selectedClass}` : "Select a class"}
        </Button>

        {txHash && (
          <Text size="1" color="green">
            Minted! tx: {txHash.slice(0, 10)}…
          </Text>
        )}
        {error && (
          <Text size="1" color="red">{error}</Text>
        )}
      </Flex>
    </Card>
  );
}
