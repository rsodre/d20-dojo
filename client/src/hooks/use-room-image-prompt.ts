import { useMemo } from "react";
import { enumVariant } from "@/utils/get-available-actions";
import type {
  Chamber,
  MonsterInstance,
  ChamberExit,
  FallenCharacter,
  CharacterStats,
  CharacterInventory,
  DungeonState,
} from "@/generated/models.gen";

export interface RoomImagePromptParams {
  chamber: Chamber | undefined;
  monster: MonsterInstance | undefined;
  exits: ChamberExit[];
  fallen: FallenCharacter[];
  stats: CharacterStats | undefined;
  inventory: CharacterInventory | undefined;
  dungeonState: DungeonState | undefined;
}

// ─── Descriptors ─────────────────────────────────────────────────────────────

const CHAMBER_BASE: Record<string, string> = {
  Entrance:
    "the grand entrance hall of an ancient Egyptian temple. Massive stone columns flank a central passage. Carved scarab reliefs and ankh symbols cover every surface. Faint daylight filters through a collapsed ceiling section above, illuminating swirling dust motes.",
  Empty:
    "a bare stone antechamber deep inside an ancient Egyptian temple. The walls are lined with faded hieroglyphic inscriptions and crumbling plaster murals depicting gods and funeral rites. Empty torch sconces jut from the walls; one gutters with a dying flame.",
  Monster:
    "a stone chamber inside an ancient Egyptian temple. The air smells of old blood and incense ash. Shattered funerary urns litter the floor. Torchlight casts long, trembling shadows across walls carved with warnings in hieroglyphics.",
  Treasure:
    "a burial antechamber laden with riches inside an ancient Egyptian temple. Gilded canopic jars line stone shelves. A carved sarcophagus dominates the far wall. Stacked offerings — alabaster vessels, lapis lazuli amulets, corroded coins — are piled around a central offering stone.",
  Trap:
    "a long stone corridor inside an ancient Egyptian temple. The floor tiles are slightly uneven; some bear faint scratch marks where stone plates have been triggered before. A row of small holes lines the upper walls. The silence is unnatural.",
  Boss:
    "the inner sanctum of an ancient Egyptian temple — the high priest's final resting chamber. Enormous obsidian obelisks stand on either side of a raised dais. A great stone altar dominates the center, stained dark. The air crackles with a cold, supernatural energy. Carved serpents and eye-of-Ra motifs cover every surface.",
  None: "a stone chamber inside an ancient Egyptian temple.",
};

const DEPTH_ATMOSPHERE: (depth: number) => string = (depth) => {
  if (depth === 0)
    return "Faint natural light reaches this chamber from the entrance. The air is dusty but breathable.";
  if (depth <= 2)
    return "Torchlight is the only illumination. The stone smells of centuries of dry desert air. Spider webs drape the upper corners.";
  if (depth <= 5)
    return "The air is heavier here, thick with the scent of old incense and stone. No light penetrates from above. The silence is total except for distant dripping water.";
  if (depth <= 9)
    return "Deep underground, the walls seem to press inward. The torches flicker without any wind. A low, subsonic hum resonates through the stone floor. The hieroglyphs here are carved differently — older, stranger.";
  return "At the deepest heart of the temple, far from any living world. The stone walls pulse faintly with a sickly golden glow emanating from veins of electrum mineral. The air is cold and charged with static. Ancient evil saturates this place.";
};

const MONSTER_DESCRIPTION: Record<string, { alive: string; dead: string }> = {
  PoisonousSnake: {
    alive:
      "A venomous serpent is coiled atop a fallen stone block in the center of the chamber, its scales iridescent black-and-gold, tongue flickering. Its golden eyes track movement.",
    dead: "The limp body of a large poisonous serpent lies sprawled across the floor, its coils still.",
  },
  Skeleton: {
    alive:
      "An ancient skeleton warrior stands vigil — bones wrapped in shreds of linen, hollow eye sockets burning with faint blue witch-fire. It clutches a corroded shortsword. Its jaw opens in a silent screech.",
    dead: "A scattered heap of bones and corroded bronze armor lies where a skeleton warrior fell. Scraps of grave-linen drift in the still air.",
  },
  Shadow: {
    alive:
      "A living shadow writhes in the darkest corner of the chamber — a humanoid void of absolute darkness that seems to drink the torchlight around it. Tendrils of darkness reach toward the warmth of living flesh.",
    dead: "A fading dark stain on the stone floor marks where a shadow creature dissolved, its edges still flickering like smoke.",
  },
  AnimatedArmor: {
    alive:
      "A towering suit of ancient Egyptian ceremonial armor stands in the center of the chamber, chest plates engraved with cartouches and falcon-headed pauldrons. It has no occupant — the armor itself moves, hollow and purposeful, its gauntleted fists clenching.",
    dead: "A collapsed pile of ancient ceremonial armor lies in a heap on the floor, its animating force extinguished. Engraved bronze plates and leather straps form a sad tangle.",
  },
  Gargoyle: {
    alive:
      "A stone gargoyle has awakened from its perch atop a carved lotus-capital pillar. Its wings are spread, each feather individually chiseled from gray granite. Its ram-headed visage glares downward with eyes of molten copper.",
    dead: "Chunks of shattered granite litter the floor — the remains of a gargoyle guardian destroyed mid-flight. Cracks radiate outward from the impact point.",
  },
  Mummy: {
    alive:
      "A mummy lurches forward from a cracked sarcophagus set into the wall — its body wound in stained linen, one arm extended, crackling with necromantic energy. The smell of natron and rot fills the chamber. Its bandaged face turns toward the intruder with unmistakable malice.",
    dead: "The unwound remains of a mummy are collapsed against the base of its sarcophagus, linen strips scattered across the floor, the necromantic fire extinguished.",
  },
  Wraith: {
    alive:
      "The spirit of the temple's high priest floats above the central altar — a spectral figure in translucent golden regalia, crook and flail held aloft, eyes blazing white. The temperature has plummeted. The torchlight barely reaches it. This is the guardian of the temple's sacred heart.",
    dead: "The shattered specter of the high priest fades — ethereal golden robes dissolving into wisps of cold light that rise toward the ceiling and vanish. An ancient curse has finally been broken.",
  },
};

const WEAPON_NAME: Record<string, string> = {
  Longsword: "a longsword",
  Dagger: "a dagger",
  Shortbow: "a shortbow",
  Greataxe: "a greataxe",
  Staff: "a gnarled wooden staff",
  None: "bare hands",
};

const ARMOR_NAME: Record<string, string> = {
  ChainMail: "chain mail armor",
  Leather: "leather armor",
  None: "no armor",
};

const CLASS_PERSPECTIVE: Record<string, string> = {
  Fighter: "A battle-hardened warrior",
  Rogue: "A nimble and cautious rogue",
  Wizard: "An arcane scholar",
  None: "An explorer",
};

// ─── Hook ─────────────────────────────────────────────────────────────────────

export function useRoomImagePrompt(params: RoomImagePromptParams): string {
  const { chamber, monster, exits, fallen, stats, inventory, dungeonState } = params;

  return useMemo(() => {
    if (!chamber) return "";

    const chamberType = enumVariant(chamber.chamber_type) as string;
    const depth = Number(chamber.chamber_id ? chamber.depth : 0);
    const exitCount = Number(chamber.exit_count);
    const difficulty = dungeonState ? Number(dungeonState.difficulty_tier) : 1;

    const parts: string[] = [];

    // ── Art style directive (leading) ──────────────────────────────────────
    parts.push(
      "First-person perspective view inside an ancient Egyptian dungeon temple, rendered in the style of Ultima Underworld — a 1990s first-person real-time 3D dungeon with texture-mapped stone walls, low-resolution pixel textures, atmospheric fog, and strong ambient occlusion. Dimly lit by flickering torches. Painterly, atmospheric, slightly dark and oppressive.",
    );

    // ── Chamber setting ────────────────────────────────────────────────────
    const baseDesc = CHAMBER_BASE[chamberType] ?? CHAMBER_BASE["None"];
    parts.push(`The scene depicts ${baseDesc}`);

    // ── Depth atmosphere ───────────────────────────────────────────────────
    parts.push(DEPTH_ATMOSPHERE(depth));

    // ── Difficulty tint ────────────────────────────────────────────────────
    if (difficulty >= 3) {
      parts.push(
        "The carvings on the walls are increasingly sinister — depictions of mass sacrifice and demonic entities. The stone itself seems darker here.",
      );
    }

    // ── Monster ────────────────────────────────────────────────────────────
    if (monster) {
      const monsterType = enumVariant(monster.monster_type) as string;
      const isAlive = monster.is_alive;
      const desc = MONSTER_DESCRIPTION[monsterType];
      if (desc) {
        parts.push(isAlive ? desc.alive : desc.dead);
        if (isAlive) {
          const hpPercent = Number(monster.max_hp) > 0
            ? Math.round((Number(monster.current_hp) / Number(monster.max_hp)) * 100)
            : 0;
          if (hpPercent < 40) {
            parts.push("The creature is visibly wounded, moving erratically.");
          }
        }
      }
    }

    // ── Fallen explorers ───────────────────────────────────────────────────
    const unlooted = fallen.filter((f) => !f.is_looted);
    const looted = fallen.filter((f) => f.is_looted);
    if (unlooted.length === 1) {
      parts.push(
        "The body of a fallen adventurer lies against the wall — their equipment scattered around them.",
      );
    } else if (unlooted.length > 1) {
      parts.push(
        `The bodies of ${unlooted.length} fallen adventurers are strewn across the chamber floor, their equipment and supplies scattered among them. This chamber has claimed many lives.`,
      );
    }
    if (looted.length > 0 && unlooted.length === 0) {
      parts.push(
        "Old bloodstains and empty pouches indicate that other adventurers have fallen and been looted here before.",
      );
    }

    // ── Treasure state ─────────────────────────────────────────────────────
    if (chamberType === "Treasure" && chamber.treasure_looted) {
      parts.push("The treasure of this chamber has already been ransacked — shelves swept bare, urns smashed.");
    }

    // ── Trap state ─────────────────────────────────────────────────────────
    if (chamberType === "Trap" && chamber.trap_disarmed) {
      parts.push("Disarmed pressure plates are visible on the floor, their mechanisms exposed and disabled.");
    }

    // ── Exits ──────────────────────────────────────────────────────────────
    if (exitCount === 0) {
      parts.push("There are no exits. This is a dead end; the only way is back.");
    } else if (exitCount === 1) {
      parts.push(
        "A single dark stone passage leads onward, framed by carved pylons with eroded falcon-headed gods.",
      );
    } else if (exitCount === 2) {
      parts.push(
        "Two dark passages lead out of the chamber in different directions, each framed by stone doorways carved with hieroglyphic warnings.",
      );
    } else {
      parts.push(
        `${exitCount} passages lead out of the chamber in different directions — a labyrinthine junction deep inside the temple.`,
      );
    }

    // ── Explorer perspective ───────────────────────────────────────────────
    if (stats && inventory) {
      const explorerClass = enumVariant(stats.character_class) as string;
      const classLabel = CLASS_PERSPECTIVE[explorerClass] ?? CLASS_PERSPECTIVE["None"];
      const primaryWeapon = enumVariant(inventory.primary_weapon) as string;
      const armorType = enumVariant(inventory.armor) as string;
      const weaponName = WEAPON_NAME[primaryWeapon] ?? "a weapon";
      const armorName = ARMOR_NAME[armorType] ?? "light clothing";
      const hp = Number(stats.current_hp);
      const maxHp = Number(stats.max_hp);
      const hpPercent = maxHp > 0 ? Math.round((hp / maxHp) * 100) : 0;

      let condition = "in good health";
      if (hpPercent <= 25) condition = "gravely wounded, blood seeping through bandages";
      else if (hpPercent <= 50) condition = "visibly injured and cautious";
      else if (hpPercent <= 75) condition = "bearing minor wounds";

      parts.push(
        `The viewer's hands hold ${weaponName}. The explorer is ${classLabel.toLowerCase()}, wearing ${armorName}, currently ${condition}.`,
      );
    }

    // ── Closing style note ─────────────────────────────────────────────────
    parts.push(
      "Render in a painterly, semi-realistic style with strong contrast between torch-lit surfaces and deep shadow. Egyptian stone textures: sandstone, basalt, alabaster. Gold leaf details on carvings. Subtle volumetric torchlight. No modern elements.",
    );

    return parts.join(" ");
  }, [chamber, monster, exits, fallen, stats, inventory, dungeonState]);
}
