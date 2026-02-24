import { useMemo } from "react";
import { useParams, Link } from "react-router-dom";
import { Badge, Button, Card, Flex, Heading, Spinner, Text } from "@radix-ui/themes";
import { useMutation } from "@tanstack/react-query";
import { CallData } from "starknet";
import { useAccount } from "@starknet-react/core";
import { useExplorerModels } from "@/hooks/use-explorer-state";
import { useChambers, useChamberExits, useFallenCharacters, useMonsterInstances } from "@/hooks/use-chambers";
import { useTempleModels } from "@/hooks/use-temple-state";
import { useRoomImagePrompt } from "@/hooks/use-room-image-prompt";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useVrfCall } from "@/hooks/use-vrf";
import { getAvailableActions, enumVariant, type Action, type GameActionContext } from "@/utils/get-available-actions";

// ─── Constants ────────────────────────────────────────────────────────────────

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

const WEAPON_LABEL: Record<string, string> = {
  Longsword: "Longsword",
  Dagger: "Dagger",
  Shortbow: "Shortbow",
  Staff: "Staff",
  None: "—",
};

const ARMOR_LABEL: Record<string, string> = {
  ChainMail: "Chain Mail",
  Leather: "Leather",
  None: "None",
};

// ─── Action execution hook ────────────────────────────────────────────────────

function useExecuteAction() {
  const { account } = useAccount();
  const { requestRandomCall } = useVrfCall();
  const { profileConfig } = useDojoConfig();
  const callData = useMemo(() => new CallData(profileConfig.manifest.abis), [profileConfig]);

  return useMutation({
    mutationFn: (action: Action) => {
      if (!account?.address) throw new Error("Not connected");
      const call = {
        contractAddress: action.contract,
        entrypoint: action.entrypoint,
        calldata: callData.compile(action.entrypoint, action.calldata as any),
      };
      const calls =
        action.needsVrf && requestRandomCall
          ? [requestRandomCall(action.contract), call]
          : [call];
      return account.execute(calls);
    },
    onSuccess: (data, action) => {
      console.log(`[PlayView] ${action.entrypoint} tx:`, data.transaction_hash);
    },
    onError: (err, action) => {
      console.error(`[PlayView] ${action.entrypoint} error:`, err);
    },
  });
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function ExplorerSheet({ characterId }: { characterId: bigint }) {
  const { stats, combat, inventory, skills } = useExplorerModels(characterId);

  const explorerClass = enumVariant(stats?.character_class);
  const emoji = CLASS_EMOJI[explorerClass] ?? "⚔️";
  const level = stats ? Number(stats.level) : "—";
  const xp = stats ? Number(stats.xp) : "—";
  const currentHp = stats ? Number(stats.current_hp) : "—";
  const maxHp = stats ? Number(stats.max_hp) : "—";
  const ac = combat ? Number(combat.armor_class) : "—";

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">
          {emoji} {explorerClass} #{characterId.toString()}
        </Heading>

        {/* Core stats */}
        <Flex gap="2" wrap="wrap">
          <Badge color="blue" size="1" variant="soft">Lv {level}</Badge>
          <Badge color="amber" size="1" variant="soft">HP {currentHp}/{maxHp}</Badge>
          <Badge color="gray" size="1" variant="soft">AC {ac}</Badge>
          <Badge color="green" size="1" variant="soft">{xp} XP</Badge>
        </Flex>

        {/* Inventory */}
        {inventory && (
          <Flex direction="column" gap="1">
            <Text size="1" color="gray" weight="bold">INVENTORY</Text>
            <Flex gap="2" wrap="wrap">
              <Badge color="bronze" size="1" variant="soft">
                {WEAPON_LABEL[enumVariant(inventory.primary_weapon)] ?? enumVariant(inventory.primary_weapon)}
              </Badge>
              {enumVariant(inventory.secondary_weapon) !== "None" && (
                <Badge color="bronze" size="1" variant="soft">
                  {WEAPON_LABEL[enumVariant(inventory.secondary_weapon)] ?? enumVariant(inventory.secondary_weapon)}
                </Badge>
              )}
              <Badge color="gray" size="1" variant="soft">
                {ARMOR_LABEL[enumVariant(inventory.armor)] ?? enumVariant(inventory.armor)}
              </Badge>
              {inventory.has_shield && (
                <Badge color="gray" size="1" variant="soft">Shield</Badge>
              )}
              {Number(inventory.gold) > 0 && (
                <Badge color="yellow" size="1" variant="soft">
                  {Number(inventory.gold)} gp
                </Badge>
              )}
              {Number(inventory.potions) > 0 && (
                <Badge color="red" size="1" variant="soft">
                  {Number(inventory.potions)} potion{Number(inventory.potions) > 1 ? "s" : ""}
                </Badge>
              )}
            </Flex>
          </Flex>
        )}

        {/* Class features */}
        {combat && explorerClass === "Wizard" && (
          <Flex direction="column" gap="1">
            <Text size="1" color="gray" weight="bold">SPELL SLOTS</Text>
            <Flex gap="2" wrap="wrap">
              <Badge color="violet" size="1" variant="soft">Lv1: {Number(combat.spell_slots_1)}</Badge>
              <Badge color="violet" size="1" variant="soft">Lv2: {Number(combat.spell_slots_2)}</Badge>
              <Badge color="violet" size="1" variant="soft">Lv3: {Number(combat.spell_slots_3)}</Badge>
            </Flex>
          </Flex>
        )}
        {combat && explorerClass === "Fighter" && (
          <Flex gap="2" wrap="wrap">
            <Badge color={combat.second_wind_used ? "gray" : "green"} size="1" variant="soft">
              Second Wind: {combat.second_wind_used ? "Used" : "Ready"}
            </Badge>
            <Badge color={combat.action_surge_used ? "gray" : "green"} size="1" variant="soft">
              Action Surge: {combat.action_surge_used ? "Used" : "Ready"}
            </Badge>
          </Flex>
        )}

        {/* Skills */}
        {skills && (
          <Flex direction="column" gap="1">
            <Text size="1" color="gray" weight="bold">SKILLS</Text>
            <Flex gap="2" wrap="wrap">
              {skills.skills.athletics && <Badge color="teal" size="1" variant="soft">Athletics</Badge>}
              {skills.skills.stealth && <Badge color="teal" size="1" variant="soft">Stealth</Badge>}
              {skills.skills.perception && <Badge color="teal" size="1" variant="soft">Perception</Badge>}
              {skills.skills.persuasion && <Badge color="teal" size="1" variant="soft">Persuasion</Badge>}
              {skills.skills.arcana && <Badge color="teal" size="1" variant="soft">Arcana</Badge>}
              {skills.skills.acrobatics && <Badge color="teal" size="1" variant="soft">Acrobatics</Badge>}
            </Flex>
          </Flex>
        )}
      </Flex>
    </Card>
  );
}

function ChamberInfo({
  dungeonId,
  chamberId,
}: {
  dungeonId: bigint;
  chamberId: bigint;
}) {
  const chambers = useChambers(dungeonId);
  const monsters = useMonsterInstances(dungeonId);
  const exits = useChamberExits(dungeonId, chamberId);
  const fallen = useFallenCharacters(dungeonId, chamberId);

  const chamber = chambers.find((c) => BigInt(c.chamber_id) === chamberId);
  const monster = monsters.find((m) => BigInt(m.chamber_id) === chamberId);

  if (!chamber) {
    return (
      <Card>
        <Flex gap="3">
          <Spinner />
          <Heading size="3">
            Chamber #{chamberId.toString()}
          </Heading>
        </Flex>
      </Card>
    );
  }

  const chamberType = enumVariant(chamber.chamber_type);
  const emoji = CHAMBER_TYPE_EMOJI[chamberType] ?? "?";
  const depth = Number(chamber.depth);
  const exitCount = Number(chamber.exit_count);

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">
          {emoji} Chamber #{chamberId.toString()} — {chamberType}
        </Heading>

        <Flex gap="2" wrap="wrap">
          <Badge color="blue" size="1" variant="soft">Depth {depth}</Badge>
          <Badge color="gray" size="1" variant="soft">
            {exitCount} exit{exitCount !== 1 ? "s" : ""}
          </Badge>
          {chamber.treasure_looted && <Badge color="amber" size="1" variant="soft">Looted</Badge>}
          {chamber.trap_disarmed && <Badge color="green" size="1" variant="soft">Trap disarmed</Badge>}
          {!chamber.trap_disarmed && chamberType === "Trap" && (
            <Badge color="orange" size="1" variant="soft">Trap DC {Number(chamber.trap_dc)}</Badge>
          )}
        </Flex>

        {/* Monster */}
        {monster && (
          <Flex gap="2" align="center">
            <Text size="2">{monster.is_alive ? "👾" : "💀"}</Text>
            <Text size="2" weight="bold">
              {MONSTER_NAME[enumVariant(monster.monster_type)] ?? enumVariant(monster.monster_type)}
            </Text>
            <Badge color={monster.is_alive ? "red" : "gray"} size="1" variant="soft">
              {monster.is_alive
                ? `${Number(monster.current_hp)}/${Number(monster.max_hp)} HP`
                : "Dead"}
            </Badge>
          </Flex>
        )}

        {/* Exits */}
        {exitCount > 0 && (
          <Flex direction="column" gap="1">
            <Text size="1" color="gray" weight="bold">EXITS</Text>
            <Flex gap="2" wrap="wrap">
              {Array.from({ length: exitCount }, (_, i) => {
                const exit = exits.find((e) => Number(BigInt(e.exit_index)) === i);
                return (
                  <Badge
                    key={i}
                    color={exit?.is_discovered ? "green" : "gray"}
                    size="1"
                    variant="soft"
                  >
                    Exit {i + 1}
                    {exit?.is_discovered
                      ? ` → Chamber #${Number(BigInt(exit.to_chamber_id))}`
                      : " (unknown)"}
                  </Badge>
                );
              })}
            </Flex>
          </Flex>
        )}

        {/* Fallen explorers */}
        {fallen.length > 0 && (
          <Flex direction="column" gap="1">
            <Text size="1" color="gray" weight="bold">FALLEN EXPLORERS</Text>
            <Flex gap="2" wrap="wrap">
              {fallen.map((f) => (
                <Badge
                  key={Number(BigInt(f.fallen_index))}
                  color={f.is_looted ? "gray" : "crimson"}
                  size="1"
                  variant="soft"
                >
                  Body #{Number(BigInt(f.fallen_index)) + 1}
                  {f.is_looted ? " (looted)" : ""}
                </Badge>
              ))}
            </Flex>
          </Flex>
        )}
      </Flex>
    </Card>
  );
}

function ActionPanel({
  ctx,
}: {
  ctx: GameActionContext;
}) {
  const actions = getAvailableActions(ctx);
  const execute = useExecuteAction();

  if (actions.length === 0) {
    return (
      <Card>
        <Text size="2" color="gray">No actions available.</Text>
      </Card>
    );
  }

  return (
    <Card>
      <Flex direction="column" gap="3">
        <Heading size="3">Actions</Heading>
        {execute.error && (
          <Text size="2" color="red">
            Error: {String(execute.error)}
          </Text>
        )}
        <Flex gap="2" wrap="wrap">
          {actions.map((action) => (
            <Button
              key={action.id}
              size="2"
              variant={action.needsVrf ? "solid" : "soft"}
              color={action.color}
              disabled={execute.isPending}
              onClick={() => execute.mutate(action)}
            >
              {execute.isPending && execute.variables?.id === action.id ? (
                <Spinner size="1" />
              ) : null}
              {action.label}
            </Button>
          ))}
        </Flex>
      </Flex>
    </Card>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export function PlayView() {
  const { dungeonId, characterId } = useParams<{ dungeonId: string; characterId: string }>();
  const dungeonIdNum = dungeonId ? BigInt(dungeonId) : undefined;
  const characterIdNum = characterId ? BigInt(characterId) : undefined;

  const { profileConfig } = useDojoConfig();
  const { stats, combat, inventory, position } = useExplorerModels(characterIdNum ?? 0n);
  const temple = useTempleModels(dungeonIdNum ?? 0n);
  const chamberId = position ? BigInt(position.chamber_id) : 0n;
  const exits = useChamberExits(dungeonIdNum ?? 0n, chamberId);
  const fallen = useFallenCharacters(dungeonIdNum ?? 0n, chamberId);
  const chambers = useChambers(dungeonIdNum ?? 0n);
  const monsters = useMonsterInstances(dungeonIdNum ?? 0n);

  const chamber = chambers.find((c) => BigInt(c.chamber_id) === chamberId);
  const monster = monsters.find((m) => BigInt(m.chamber_id) === chamberId);

  const imagePrompt = useRoomImagePrompt({
    chamber,
    monster,
    exits,
    fallen,
    stats,
    inventory,
    dungeonState: temple?.state,
  });

  if (!dungeonIdNum || !characterIdNum) {
    return (
      <Flex direction="column" gap="4">
        <Text color="red">Invalid URL parameters.</Text>
        <Link to="/"><Button variant="soft">Back to Lobby</Button></Link>
      </Flex>
    );
  }

  const explorerClass = enumVariant(stats?.character_class);
  const isDead = stats?.is_dead ?? false;
  const inCombat = position?.in_combat ?? false;

  const ctx: GameActionContext = {
    characterId: characterIdNum,
    explorerClass,
    level: stats ? Number(stats.level) : 1,
    isDead,
    inCombat,
    dungeonId: dungeonIdNum,
    chamberId,
    potions: inventory ? Number(inventory.potions) : 0,
    secondWindUsed: combat?.second_wind_used ?? false,
    spellSlots1: combat ? Number(combat.spell_slots_1) : 0,
    spellSlots2: combat ? Number(combat.spell_slots_2) : 0,
    spellSlots3: combat ? Number(combat.spell_slots_3) : 0,
    chamberType: chamber ? enumVariant(chamber.chamber_type) : "None",
    exitCount: chamber ? Number(chamber.exit_count) : 0,
    treasureLooted: chamber?.treasure_looted ?? false,
    trapDisarmed: chamber?.trap_disarmed ?? false,
    exits,
    fallenExplorers: fallen,
    contracts: {
      temple: profileConfig.contractAddresses.temple,
      combat: profileConfig.contractAddresses.combat,
    },
  };

  const difficultyLabel = temple?.state
    ? `Difficulty ${Number(temple.state.difficulty_tier)}`
    : "";

  return (
    <Flex direction="column" gap="4">
      {/* Header */}
      <Flex align="center" gap="3">
        <Link to="/">
          <Button variant="ghost" size="2">← Lobby</Button>
        </Link>
        <Link to={`/temple/${dungeonId}`}>
          <Button variant="ghost" size="2">🏛️ Temple #{dungeonId}</Button>
        </Link>
        {difficultyLabel && (
          <Badge color="amber" variant="soft">{difficultyLabel}</Badge>
        )}
        {inCombat && <Badge color="red" variant="soft">⚔️ In Combat</Badge>}
        {isDead && <Badge color="gray" variant="soft">💀 Dead</Badge>}
      </Flex>

      {/* Two-column layout: explorer sheet + chamber info */}
      <Flex gap="4" direction={{ initial: "column", sm: "row" }}>
        <div style={{ flex: 1 }}>
          <ExplorerSheet characterId={characterIdNum} />
        </div>
        <div style={{ flex: 1 }}>
          {chamberId > 0n ? (
            <ChamberInfo dungeonId={dungeonIdNum} chamberId={chamberId} />
          ) : (
            <Card>
              <Text size="2" color="gray">Not in a chamber.</Text>
            </Card>
          )}
        </div>
      </Flex>

      {/* Action panel */}
      {isDead ? (
        <Card>
          <Flex direction="column" gap="3" align="center">
            <Text size="4">💀 Your explorer has fallen.</Text>
            <Link to="/">
              <Button>Mint New Explorer</Button>
            </Link>
          </Flex>
        </Card>
      ) : (
        <ActionPanel ctx={ctx} />
      )}

      {/* Image generation prompt */}
      {imagePrompt && (
        <Card>
          <Flex direction="column" gap="2">
            <Text size="1" color="gray" weight="bold">IMAGE PROMPT</Text>
            <Text
              size="1"
              style={{
                fontFamily: "monospace",
                whiteSpace: "pre-wrap",
                wordBreak: "break-word",
                color: "var(--gray-11)",
                lineHeight: "1.6",
              }}
            >
              {imagePrompt}
            </Text>
          </Flex>
        </Card>
      )}
    </Flex>
  );
}
