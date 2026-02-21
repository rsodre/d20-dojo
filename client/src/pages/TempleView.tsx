import { useParams, Link } from "react-router-dom";
import { Badge, Button, Card, Flex, Grid, Heading, Text } from "@radix-ui/themes";
import { useTempleModels } from "@/hooks/use-temple-state";
import { useExplorerModels } from "@/hooks/use-explorer-state";
import { useChambers, useMonsterInstances } from "@/hooks/use-chambers";
import { usePlayerTokensContext } from "@/contexts/player-tokens-provider";
import type { Chamber, MonsterInstance } from "@/generated/models.gen";

// ─── helpers ─────────────────────────────────────────────────────────────────

const DIFFICULTY_LABEL: Record<number, string> = {
  1: "Easy",
  2: "Medium",
  3: "Hard",
  5: "Legendary",
};

const CLASS_EMOJI: Record<string, string> = {
  Fighter: "⚔️",
  Rogue: "🗡️",
  Wizard: "🧙",
};

const CHAMBER_TYPE_EMOJI: Record<string, string> = {
  Entrance: "🚪",
  Empty: "○",
  Monster: "👾",
  Treasure: "💰",
  Trap: "⚠️",
  Boss: "💀",
  None: "?",
};

const MONSTER_NAME: Record<string, string> = {
  PoisonousSnake: "Poisonous Snake",
  Skeleton: "Skeleton",
  Shadow: "Shadow",
  AnimatedArmor: "Animated Armor",
  Gargoyle: "Gargoyle",
  Mummy: "Mummy",
  Wraith: "Wraith",
  None: "—",
};

function enumVariant(value: unknown): string {
  if (!value) return "None";
  if (typeof value === "object" && "activeVariant" in (value as object)) {
    return (value as { activeVariant: () => string }).activeVariant();
  }
  return String(value);
}

// ─── sub-components ──────────────────────────────────────────────────────────

function ChamberCard({
  chamber,
  monster,
  isBoss,
}: {
  chamber: Chamber;
  monster: MonsterInstance | undefined;
  isBoss: boolean;
}) {
  const chamberId = Number(chamber.chamber_id);
  const depth = Number(chamber.depth);
  const exitCount = Number(chamber.exit_count);
  const chamberType = enumVariant(chamber.chamber_type);
  const emoji = CHAMBER_TYPE_EMOJI[chamberType] ?? "?";

  return (
    <Card>
      <Flex direction="column" gap="2">
        <Flex align="center" gap="2">
          <Text size="2">{emoji}</Text>
          <Text size="2" weight="bold">
            Chamber #{chamberId}
          </Text>
          {isBoss && (
            <Badge color="crimson" size="1">Boss</Badge>
          )}
          <Badge color="gray" size="1" variant="soft">
            {chamberType}
          </Badge>
        </Flex>

        <Flex gap="2" wrap="wrap">
          <Badge color="purple" size="1" variant="soft">
            Depth {depth}
          </Badge>
          <Badge color="gray" size="1" variant="soft">
            {exitCount} exit{exitCount !== 1 ? "s" : ""}
          </Badge>

          {chamber.treasure_looted && (
            <Badge color="amber" size="1" variant="soft">Looted</Badge>
          )}
          {chamber.trap_disarmed && (
            <Badge color="green" size="1" variant="soft">Trap disarmed</Badge>
          )}
          {!chamber.trap_disarmed && chamberType === "Trap" && (
            <Badge color="orange" size="1" variant="soft">Trap DC {Number(chamber.trap_dc)}</Badge>
          )}

          {monster && (
            <Badge color={monster.is_alive ? "red" : "gray"} size="1" variant="soft">
              {MONSTER_NAME[enumVariant(monster.monster_type)] ?? enumVariant(monster.monster_type)}
              {" "}
              {monster.is_alive
                ? `${Number(monster.current_hp)}/${Number(monster.max_hp)} HP`
                : "(dead)"}
            </Badge>
          )}
        </Flex>
      </Flex>
    </Card>
  );
}

function TempleStats({ templeId }: { templeId: bigint }) {
  const temple = useTempleModels(templeId);
  const state = temple?.state;

  if (!state) {
    return <Text size="2" color="gray">Loading temple state...</Text>;
  }

  const difficulty = Number(state.difficulty_tier);
  const difficultyLabel = DIFFICULTY_LABEL[difficulty] ?? `Tier ${difficulty}`;
  const bossAlive = state.boss_alive;
  const maxDepth = Number(state.max_depth);
  const nextChamberId = Number(state.next_chamber_id);
  const bossChamber = Number(state.boss_chamber_id);

  return (
    <Flex gap="2" wrap="wrap">
      <Badge color="amber" size="2" variant="soft">{difficultyLabel}</Badge>
      <Badge color={bossAlive ? "red" : "green"} size="2" variant="soft">
        Boss: {bossAlive ? "Alive" : "Defeated"}
      </Badge>
      <Badge color="blue" size="2" variant="soft">
        Chambers: {nextChamberId - 1}
      </Badge>
      <Badge color="purple" size="2" variant="soft">
        Max Depth: {maxDepth}
      </Badge>
      {bossChamber > 0 && (
        <Badge color="crimson" size="2" variant="soft">
          Boss Chamber: #{bossChamber}
        </Badge>
      )}
    </Flex>
  );
}

function ExplorerInTemple({ explorerId }: { explorerId: bigint }) {
  const { stats, health, combat, position } = useExplorerModels(explorerId);

  if (!position || BigInt(position.dungeon_id) === 0n) return null;

  const className = enumVariant(stats?.adventurer_class);
  const emoji = CLASS_EMOJI[className] ?? "⚔️";
  const level = stats ? Number(stats.level) : undefined;
  const currentHp = health ? Number(health.current_hp) : undefined;
  const maxHp = health ? Number(health.max_hp) : undefined;
  const ac = combat ? Number(combat.armor_class) : undefined;
  const isDead = health?.is_dead ?? false;
  const inCombat = position?.in_combat ?? false;
  const chamberId = position ? Number(position.chamber_id) : undefined;

  return (
    <Card>
      <Flex direction="column" gap="2">
        <Flex align="center" gap="2">
          <Text size="2">{emoji}</Text>
          <Text size="2" weight="bold">
            {className !== "None" ? className : "Explorer"} #{explorerId.toString()}
          </Text>
          {chamberId !== undefined && chamberId > 0 && (
            <Badge color="green" size="1" variant="soft">Chamber #{chamberId}</Badge>
          )}
        </Flex>
        <Flex gap="2" wrap="wrap">
          {level !== undefined && (
            <Badge color="blue" size="1" variant="soft">Lv {level}</Badge>
          )}
          {currentHp !== undefined && maxHp !== undefined && (
            <Badge color="amber" size="1" variant="soft">HP {currentHp}/{maxHp}</Badge>
          )}
          {ac !== undefined && (
            <Badge color="gray" size="1" variant="soft">AC {ac}</Badge>
          )}
          {isDead && <Badge color="red" size="1">Dead</Badge>}
          {inCombat && <Badge color="orange" size="1">In Combat</Badge>}
        </Flex>
      </Flex>
    </Card>
  );
}

/** Renders only if the explorer is in this temple */
function ExplorerInTempleGate({
  explorerId,
  templeId,
}: {
  explorerId: bigint;
  templeId: bigint;
}) {
  const { position } = useExplorerModels(explorerId);
  if (!position || BigInt(position.dungeon_id) !== templeId) return null;
  return <ExplorerInTemple explorerId={explorerId} />;
}

// ─── main view ───────────────────────────────────────────────────────────────

export function TempleView() {
  const { templeId } = useParams<{ templeId: string }>();
  const templeIdNum = templeId ? BigInt(templeId) : undefined;

  const { explorers } = usePlayerTokensContext();

  const temple = useTempleModels(templeIdNum ?? 0n);
  const chambers = useChambers(templeIdNum ?? 0n);
  const monsters = useMonsterInstances(templeIdNum ?? 0n);
  const bossChamber = temple?.state ? Number(temple.state.boss_chamber_id) : 0;

  // Build monster lookup: chamberId → MonsterInstance
  const monsterByChamberId = new Map<number, MonsterInstance>();
  for (const m of monsters) {
    monsterByChamberId.set(Number(m.chamber_id), m);
  }

  if (!templeIdNum) {
    return (
      <Flex direction="column" gap="4">
        <Text color="red">Invalid temple ID.</Text>
        <Link to="/"><Button variant="soft">Back to Lobby</Button></Link>
      </Flex>
    );
  }

  return (
    <Flex direction="column" gap="4">
      {/* Header */}
      <Flex align="center" gap="3">
        <Link to="/">
          <Button variant="ghost" size="2">← Back</Button>
        </Link>
        <Heading size="5">🏛️ Temple #{templeId}</Heading>
      </Flex>

      {/* Temple state */}
      <Card>
        <Flex direction="column" gap="3">
          <Heading size="3">Temple State</Heading>
          <TempleStats templeId={templeIdNum} />
        </Flex>
      </Card>

      {/* Chambers */}
      <Card>
        <Flex direction="column" gap="3">
          <Flex align="center" gap="2">
            <Heading size="3">Chambers</Heading>
            <Badge color="gray" variant="soft">{chambers.length}</Badge>
          </Flex>

          {chambers.length === 0 ? (
            <Text size="2" color="gray">No chambers discovered yet.</Text>
          ) : (
            <Grid columns={{ initial: "1", sm: "2", md: "4" }} gap="2">
              {chambers.map((chamber) => (
                <ChamberCard
                  key={Number(chamber.chamber_id)}
                  chamber={chamber}
                  monster={monsterByChamberId.get(Number(chamber.chamber_id))}
                  isBoss={Number(chamber.chamber_id) === bossChamber}
                />
              ))}
            </Grid>
          )}
        </Flex>
      </Card>

      {/* Explorers in temple */}
      <Card>
        <Flex direction="column" gap="3">
          <Flex align="center" gap="2">
            <Heading size="3">Explorers Inside</Heading>
            {/* <Badge color="gray" variant="soft">{explorers.length}</Badge> */}
          </Flex>

          {explorers.length === 0 ? (
            <Text size="2" color="gray">No explorers in this temple.</Text>
          ) : (
            <Grid columns={{ initial: "1", sm: "2", md: "4" }} gap="2">
              {explorers.map((token) => (
                <ExplorerInTempleGate
                  key={token.tokenId}
                  explorerId={token.tokenIdNum}
                  templeId={templeIdNum}
                />
              ))}
            </Grid>
          )}
        </Flex>
      </Card>

    </Flex>
  );
}
