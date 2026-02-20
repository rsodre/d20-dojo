import { useState } from "react";
import { Button, Card, Flex, Heading, Text } from "@radix-ui/themes";
import { useAccount } from "@starknet-react/core";
import { CallData } from "starknet";
import { useDojoConfig } from "@/contexts/dojo-config-provider";

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
  const { account } = useAccount();
  const { profileConfig } = useDojoConfig();

  const [difficulty, setDifficulty] = useState<number | null>(null);
  const [isPending, setIsPending] = useState(false);
  const [txHash, setTxHash] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleMint = async () => {
    if (!account || difficulty === null) return;

    setIsPending(true);
    setTxHash(null);
    setError(null);

    try {
      const result = await account.execute([
        {
          contractAddress: profileConfig.contractAddresses.temple,
          entrypoint: "mint_temple",
          calldata: CallData.compile([difficulty]),
        },
      ]);
      setTxHash(result.transaction_hash);
    } catch (err: any) {
      setError(err?.message ?? String(err));
    } finally {
      setIsPending(false);
    }
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
          disabled={!account || difficulty === null || isPending}
          loading={isPending}
          color="amber"
        >
          {difficulty !== null
            ? `Mint ${DIFFICULTIES.find((d) => d.value === difficulty)?.label} Temple`
            : "Select difficulty"}
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
