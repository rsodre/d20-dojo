import { Link } from "react-router-dom";
import { Badge, Button, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { useAllTemples } from "@/hooks/use-all-temples";
import type { TokenInfo } from "@/hooks/use-player-tokens";

interface TempleCardProps {
  token: TokenInfo;
  selected: boolean;
  onSelect: (id: bigint) => void;
}

function TempleCard({ token, selected, onSelect }: TempleCardProps) {
  return (
    <Card
      style={{
        cursor: "pointer",
        outline: selected ? "2px solid var(--amber-9)" : undefined,
      }}
      onClick={() => onSelect(token.tokenIdNum)}
    >
      <Flex align="center" justify="between" gap="2">
        <Flex align="center" gap="2">
          <Text size="2">🏛️</Text>
          <Text size="2" weight="bold">Temple #{token.tokenIdNum.toString()}</Text>
          {selected && <Badge color="amber" size="1">Selected</Badge>}
        </Flex>
        <Link
          to={`/temple/${token.tokenIdNum.toString()}`}
          style={{ textDecoration: "none" }}
          onClick={(e) => e.stopPropagation()}
        >
          <Button size="1" variant="ghost">View →</Button>
        </Link>
      </Flex>
    </Card>
  );
}

interface TempleListProps {
  selectedTempleId: bigint | null;
  onSelectTemple: (id: bigint) => void;
}

export function TempleList({ selectedTempleId, onSelectTemple }: TempleListProps) {
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
            <TempleCard
              key={`${token.contractAddress}:${token.tokenId}`}
              token={token}
              selected={selectedTempleId === token.tokenIdNum}
              onSelect={onSelectTemple}
            />
          ))}
        </Flex>
      </Flex>
    </Card>
  );
}
