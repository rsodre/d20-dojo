import { Badge, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { usePlayerTokensContext, type TokenInfo } from "@/contexts/player-tokens-provider";
import { useExplorerModels } from "@/hooks/use-explorer-state";
import { useAccount } from "@starknet-react/core";

const CLASS_EMOJI: Record<string, string> = {
  Fighter: "⚔️",
  Rogue: "🗡️",
  Wizard: "🧙",
};

function ExplorerCard({ token }: { token: TokenInfo }) {
  const { stats, health, combat } = useExplorerModels(token.tokenIdNum);

  // console.log("ExplorerCard", { stats, health, combat });

  const className = stats?.explorer_class as unknown as string ?? undefined;
  const emoji = className ? (CLASS_EMOJI[className] ?? "⚔️") : "⚔️";
  const level = stats ? Number(stats.level) : undefined;
  const xp = stats ? Number(stats.xp) : undefined;
  const currentHp = health ? Number(health.current_hp) : undefined;
  const maxHp = health ? Number(health.max_hp) : undefined;
  const ac = combat ? Number(combat.armor_class) : undefined;
  const isDead = health?.is_dead ?? false;

  return (
    <Card>
      <Flex direction="column" gap="2">
        <Flex align="center" gap="2">
          <Text size="2">{emoji}</Text>
          <Text size="2" weight="bold">
            {className ?? "Explorer"} #{token.tokenIdNum.toString()}
          </Text>
          {isDead && <Badge color="red" size="1">Dead</Badge>}
        </Flex>

        {stats ? (
          <Flex gap="2" wrap="wrap">
            <Badge color="blue" size="1" variant="soft">
              Lv {level}
            </Badge>
            <Badge color="amber" size="1" variant="soft">
              HP {currentHp}/{maxHp}
            </Badge>
            <Badge color="gray" size="1" variant="soft">
              AC {ac}
            </Badge>
            <Badge color="green" size="1" variant="soft">
              {xp} XP
            </Badge>
          </Flex>
        ) : (
          <Badge color="gray" size="1" variant="soft">
            Token #{token.tokenIdNum.toString()}
          </Badge>
        )}
      </Flex>
    </Card>
  );
}

export function ExplorerList() {
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

        {!isConnected ? <Text color="gray">Connect Cotnroller to see your explorers</Text> :
          isLoading ? <Spinner size="1" /> :
            explorers.length === 0 ? (
              <Text color="gray">No explorers yet. Mint one to begin.</Text>
            ) : (
              <Flex direction="column" gap="2">
                {explorers.map((token) => (
                  <ExplorerCard key={`${token.contractAddress}:${token.tokenId}`} token={token} />
                ))}
              </Flex>
            )
          }
      </Flex>
    </Card>
  );
}
