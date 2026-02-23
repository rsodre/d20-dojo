import { Link } from "react-router-dom";
import { Badge, Button, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { usePlayerTokensContext, type TokenInfo } from "@/contexts/player-tokens-provider";
import { useExplorerModels } from "@/hooks/use-explorer-state";
import { useTempleCalls } from "@/hooks/use-temple-calls";
import { useAccount } from "@starknet-react/core";

const CLASS_EMOJI: Record<string, string> = {
  Fighter: "⚔️",
  Rogue: "🗡️",
  Wizard: "🧙",
};

interface ExplorerCardProps {
  token: TokenInfo;
  selectedTempleId: bigint | null;
}

function ExplorerCard({ token, selectedTempleId }: ExplorerCardProps) {
  const { stats, combat, position } = useExplorerModels(token.tokenIdNum);
  const { enter_temple, exit_temple } = useTempleCalls();

  const className = stats?.character_class as unknown as string ?? undefined;
  const emoji = className ? (CLASS_EMOJI[className] ?? "⚔️") : "⚔️";
  const level = stats ? Number(stats.level) : undefined;
  const xp = stats ? Number(stats.xp) : undefined;
  const currentHp = stats ? Number(stats.current_hp) : undefined;
  const maxHp = stats ? Number(stats.max_hp) : undefined;
  const ac = combat ? Number(combat.armor_class) : undefined;
  const isDead = stats?.is_dead ?? false;

  const dungeonId = position ? BigInt(position.dungeon_id) : 0n;
  const isInTemple = dungeonId > 0n;

  const isPending = enter_temple.isPending || exit_temple.isPending;

  return (
    <Card>
      <Flex direction="column" gap="2">
        <Flex align="center" gap="2">
          <Text size="2">{emoji}</Text>
          <Text size="2" weight="bold">
            {className ?? "Explorer"} #{token.tokenIdNum.toString()}
          </Text>
          {isDead && <Badge color="red" size="1">Dead</Badge>}
          {isInTemple && <Badge color="green" size="1">In Temple #{dungeonId.toString()}</Badge>}
        </Flex>

        {stats ? (
          <Flex gap="2" wrap="wrap">
            <Badge color="blue" size="1" variant="soft">Lv {level}</Badge>
            <Badge color="amber" size="1" variant="soft">HP {currentHp}/{maxHp}</Badge>
            <Badge color="gray" size="1" variant="soft">AC {ac}</Badge>
            <Badge color="green" size="1" variant="soft">{xp} XP</Badge>
          </Flex>
        ) : (
          <Badge color="gray" size="1" variant="soft">
            Token #{token.tokenIdNum.toString()}
          </Badge>
        )}

        {!isDead && (
          <Flex gap="2" wrap="wrap">
            {!isInTemple && selectedTempleId !== null && (
              <Button
                size="1"
                disabled={isPending}
                loading={enter_temple.isPending}
                onClick={() =>
                  enter_temple.mutate({ characterId: token.tokenIdNum, dungeonId: selectedTempleId })
                }
              >
                Enter Temple #{selectedTempleId.toString()}
              </Button>
            )}
            {!isInTemple && selectedTempleId === null && (
              <Text size="1" color="gray">Select a temple to enter</Text>
            )}
            {isInTemple && (
              <>
                <Link to={`/play/${dungeonId}/${token.tokenIdNum}`} style={{ textDecoration: "none" }}>
                  <Button size="1" color="amber">Play →</Button>
                </Link>
                <Button
                  size="1"
                  variant="soft"
                  color="red"
                  disabled={isPending}
                  loading={exit_temple.isPending}
                  onClick={() => exit_temple.mutate(token.tokenIdNum)}
                >
                  Exit Temple
                </Button>
              </>
            )}
          </Flex>
        )}
      </Flex>
    </Card>
  );
}

interface ExplorerListProps {
  selectedTempleId: bigint | null;
}

export function ExplorerList({ selectedTempleId }: ExplorerListProps) {
  const { isConnected } = useAccount();
  const { explorers, isLoading } = usePlayerTokensContext();

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Flex align="center" gap="2">
          <Heading size="3">My Explorers</Heading>
          {isLoading && <Spinner size="1" />}
          {!isLoading && (
            <Badge color="gray" variant="soft">{explorers.length}</Badge>
          )}
        </Flex>

        {!isConnected ? <Text color="gray">Connect Controller to see your explorers</Text> :
          isLoading ? <Spinner size="1" /> :
            explorers.length === 0 ? (
              <Text color="gray">No explorers yet. Mint one to begin.</Text>
            ) : (
              <Flex direction="column" gap="2">
                {explorers.map((token) => (
                  <ExplorerCard
                    key={`${token.contractAddress}:${token.tokenId}`}
                    token={token}
                    selectedTempleId={selectedTempleId}
                  />
                )).reverse()}
              </Flex>
            )
        }
      </Flex>
    </Card>
  );
}
