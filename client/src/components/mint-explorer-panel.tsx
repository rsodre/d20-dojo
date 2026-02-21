import { useState } from "react";
import { Button, Card, Flex, Heading, Text } from "@radix-ui/themes";
import { useExplorerCalls } from "@/hooks/use-explorer-calls";
import { useAccount } from "@starknet-react/core";

type AdventurerClass = "Fighter" | "Rogue" | "Wizard";

const CLASS_INFO: Record<AdventurerClass, { label: string; desc: string; emoji: string }> = {
  Fighter: { label: "Fighter", desc: "d10 HP · Longsword · Chain Mail AC 16", emoji: "⚔️" },
  Rogue: { label: "Rogue", desc: "d8 HP · Dagger + Shortbow · Leather AC", emoji: "🗡️" },
  Wizard: { label: "Wizard", desc: "d6 HP · Staff · Spells · AC 10+DEX", emoji: "🧙" },
};

export function MintExplorerPanel() {
  const { isConnected } = useAccount();
  const { mint_explorer } = useExplorerCalls();

  const [selectedClass, setSelectedClass] = useState<AdventurerClass | null>(null);
  const [txHash, setTxHash] = useState<string | null>(null);

  const canMint = mint_explorer && selectedClass;
  const handleMint = async () => {
    if (canMint) {
      setTxHash(null);
      const result = await mint_explorer.mutateAsync(selectedClass);
      setTxHash(result.transaction_hash);
    }
  };

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">Mint Explorer</Heading>
        <Text size="2" color="gray">Choose your class — stats are randomized by VRF on-chain.</Text>

        <Flex gap="2" wrap="wrap">
          {(Object.keys(CLASS_INFO) as AdventurerClass[]).map((cls) => {
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
          disabled={!canMint || mint_explorer?.isPending || !isConnected}
          loading={mint_explorer.isPending}
          color="amber"
        >
          {!selectedClass ? "Select a class" : !isConnected ? "Connect Cotnroller to mint" : `Mint ${selectedClass}`}
        </Button>

        {txHash && (
          <Text size="1" color="green">
            Minted! tx: {txHash.slice(0, 10)}…
          </Text>
        )}
        {mint_explorer.error && (
          <Text size="1" color="red">{mint_explorer.error.toString()}</Text>
        )}
      </Flex>
    </Card>
  );
}
