import { Link } from "react-router-dom";
import { Badge, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { useAllTemples } from "@/hooks/use-all-temples";
import type { TokenInfo } from "@/hooks/use-player-tokens";

function TempleCard({ token }: { token: TokenInfo }) {
  return (
    <Link to={`/temple/${token.tokenIdNum.toString()}`} style={{ textDecoration: "none" }}>
      <Card style={{ cursor: "pointer" }}>
        <Flex direction="column" gap="1">
          <Flex align="center" gap="2">
            <Text size="2">🏛️</Text>
            <Text size="2" weight="bold">Temple #{token.tokenIdNum.toString()}</Text>
          </Flex>
          <Badge color="blue" size="1" variant="soft">
            Token ID: {token.tokenIdNum.toString()}
          </Badge>
        </Flex>
      </Card>
    </Link>
  );
}

export function TempleList() {
  const { temples, isLoading } = useAllTemples();

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Flex align="center" gap="2">
          <Heading size="3">Existing Temples</Heading>
          {isLoading && <Spinner size="1" />}
          {!isLoading && (
            <Badge color="gray" variant="soft">{temples.length}</Badge>
          )}
        </Flex>

        {!isLoading && temples.length === 0 && (
          <Text size="2" color="gray">No temples minted yet.</Text>
        )}

        <Flex direction="column" gap="2">
          {temples.map((token) => (
            <TempleCard key={`${token.contractAddress}:${token.tokenId}`} token={token} />
          ))}
        </Flex>
      </Flex>
    </Card>
  );
}
