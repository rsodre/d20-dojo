import { useState } from "react";
import { Button, Card, Flex, Heading, Text } from "@radix-ui/themes";
import { useTempleCalls } from "@/hooks/use-temple-calls";

interface DifficultyOption {
  value: number;
  label: string;
  desc: string;
}

const DIFFICULTIES: DifficultyOption[] = [
  { value: 1, label: "Easy",      desc: "Snakes & Skeletons" },
  { value: 2, label: "Medium",    desc: "Shadows & Armor"    },
  { value: 3, label: "Hard",      desc: "Gargoyles & Mummies" },
  { value: 5, label: "Legendary", desc: "Wraith awaits"      },
];

export function MintTemplePanel() {
  const { mint_temple } = useTempleCalls();

  const [difficulty, setDifficulty] = useState<number | null>(null);

  const canMint = mint_temple && difficulty !== null;
  const handleMint = () => {
    if (canMint) mint_temple.mutate(difficulty);
  };

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">Mint Temple</Heading>
        <Text size="2" color="gray">Choose difficulty — chambers and monsters scale with it.</Text>

        <Flex gap="2" wrap="wrap">
          {DIFFICULTIES.map(({ value, label, desc }) => {
            const isSelected = difficulty === value;
            return (
              <Card
                key={value}
                onClick={() => setDifficulty(value)}
                style={{
                  cursor: "pointer",
                  flex: "1 1 110px",
                  border: isSelected ? "2px solid var(--amber-9)" : "2px solid transparent",
                  background: isSelected ? "var(--amber-2)" : undefined,
                }}
              >
                <Flex direction="column" gap="1" align="center">
                  <Text weight="bold" size="2">{label}</Text>
                  <Text size="1" color="gray" align="center">{desc}</Text>
                </Flex>
              </Card>
            );
          })}
        </Flex>

        <Button
          onClick={handleMint}
          disabled={!canMint || mint_temple?.isPending}
          loading={mint_temple.isPending}
          color="amber"
        >
          {difficulty !== null
            ? `Mint ${DIFFICULTIES.find((d) => d.value === difficulty)?.label} Temple`
            : "Select difficulty"}
        </Button>

        {mint_temple.isSuccess && (
          <Text size="1" color="green">
            Minted! tx: {mint_temple.data?.transaction_hash.slice(0, 10)}…
          </Text>
        )}
        {mint_temple.isError && (
          <Text size="1" color="red">{(mint_temple.error as any)?.message ?? String(mint_temple.error)}</Text>
        )}
      </Flex>
    </Card>
  );
}
