import { Badge, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { usePlayerTokensContext, type TokenInfo } from "@/contexts/player-tokens-provider";

function ExplorerCard({ token }: { token: TokenInfo }) {
  return (
    <Card>
      <Flex direction="column" gap="1">
        <Flex align="center" gap="2">
          <Text size="2">⚔️</Text>
          <Text size="2" weight="bold">Explorer #{token.tokenIdNum.toString()}</Text>
        </Flex>
        <Badge color="amber" size="1" variant="soft">
          Token ID: {token.tokenIdNum.toString()}
        </Badge>
      </Flex>
    </Card>
  );
}

export function ExplorerList() {
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

        {!isLoading && explorers.length === 0 && (
          <Text size="2" color="gray">No explorers yet. Mint one to begin.</Text>
        )}

        <Flex direction="column" gap="2">
          {explorers.map((token) => (
            <ExplorerCard key={`${token.contractAddress}:${token.tokenId}`} token={token} />
          ))}
        </Flex>
      </Flex>
    </Card>
  );
}
