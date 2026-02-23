import type { SchemaType as ISchemaType } from "@dojoengine/sdk";

import { CairoCustomEnum, BigNumberish } from 'starknet';

// Type definition for `d20::d20::models::character::AbilityScore` struct
export interface AbilityScore {
	strength: BigNumberish;
	dexterity: BigNumberish;
	constitution: BigNumberish;
	intelligence: BigNumberish;
	wisdom: BigNumberish;
	charisma: BigNumberish;
}

// Type definition for `d20::d20::models::character::CharacterCombat` struct
export interface CharacterCombat {
	character_id: BigNumberish;
	armor_class: BigNumberish;
	spell_slots_1: BigNumberish;
	spell_slots_2: BigNumberish;
	spell_slots_3: BigNumberish;
	second_wind_used: boolean;
	action_surge_used: boolean;
}

// Type definition for `d20::d20::models::character::CharacterInventory` struct
export interface CharacterInventory {
	character_id: BigNumberish;
	primary_weapon: WeaponTypeEnum;
	secondary_weapon: WeaponTypeEnum;
	armor: ArmorTypeEnum;
	has_shield: boolean;
	gold: BigNumberish;
	potions: BigNumberish;
}

// Type definition for `d20::d20::models::character::CharacterPosition` struct
export interface CharacterPosition {
	character_id: BigNumberish;
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	in_combat: boolean;
	combat_monster_id: BigNumberish;
}

// Type definition for `d20::d20::models::character::CharacterSkills` struct
export interface CharacterSkills {
	character_id: BigNumberish;
	skills: SkillsSet;
	expertise_1: SkillEnum;
	expertise_2: SkillEnum;
}

// Type definition for `d20::d20::models::character::CharacterStats` struct
export interface CharacterStats {
	character_id: BigNumberish;
	abilities: AbilityScore;
	level: BigNumberish;
	xp: BigNumberish;
	character_class: CharacterClassEnum;
	dungeons_conquered: BigNumberish;
	current_hp: BigNumberish;
	max_hp: BigNumberish;
	is_dead: boolean;
}

// Type definition for `d20::d20::models::character::SkillsSet` struct
export interface SkillsSet {
	athletics: boolean;
	stealth: boolean;
	perception: boolean;
	persuasion: boolean;
	arcana: boolean;
	acrobatics: boolean;
}

// Type definition for `d20::d20::models::dungeon::Chamber` struct
export interface Chamber {
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	chamber_type: ChamberTypeEnum;
	depth: BigNumberish;
	exit_count: BigNumberish;
	is_revealed: boolean;
	treasure_looted: boolean;
	trap_disarmed: boolean;
	trap_dc: BigNumberish;
	fallen_count: BigNumberish;
}

// Type definition for `d20::d20::models::dungeon::ChamberExit` struct
export interface ChamberExit {
	dungeon_id: BigNumberish;
	from_chamber_id: BigNumberish;
	exit_index: BigNumberish;
	to_chamber_id: BigNumberish;
	is_discovered: boolean;
}

// Type definition for `d20::d20::models::dungeon::CharacterDungeonProgress` struct
export interface CharacterDungeonProgress {
	character_id: BigNumberish;
	dungeon_id: BigNumberish;
	chambers_explored: BigNumberish;
	xp_earned: BigNumberish;
}

// Type definition for `d20::d20::models::dungeon::DungeonState` struct
export interface DungeonState {
	dungeon_id: BigNumberish;
	difficulty_tier: BigNumberish;
	next_chamber_id: BigNumberish;
	boss_chamber_id: BigNumberish;
	boss_alive: boolean;
	max_depth: BigNumberish;
}

// Type definition for `d20::d20::models::dungeon::FallenCharacter` struct
export interface FallenCharacter {
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	fallen_index: BigNumberish;
	character_id: BigNumberish;
	dropped_weapon: WeaponTypeEnum;
	dropped_armor: ArmorTypeEnum;
	dropped_gold: BigNumberish;
	dropped_potions: BigNumberish;
	is_looted: boolean;
}

// Type definition for `d20::d20::models::monster::MonsterInstance` struct
export interface MonsterInstance {
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	monster_id: BigNumberish;
	monster_type: MonsterTypeEnum;
	current_hp: BigNumberish;
	max_hp: BigNumberish;
	is_alive: boolean;
}

// Type definition for `d20::models::config::Config` struct
export interface Config {
	key: BigNumberish;
	vrf_address: string;
}

// Type definition for `d20::d20::models::events::BossDefeated` struct
export interface BossDefeated {
	dungeon_id: BigNumberish;
	character_id: BigNumberish;
	monster_type: MonsterTypeEnum;
}

// Type definition for `d20::d20::models::events::ChamberRevealed` struct
export interface ChamberRevealed {
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	chamber_type: ChamberTypeEnum;
	depth: BigNumberish;
	revealed_by: BigNumberish;
}

// Type definition for `d20::d20::models::events::CharacterDied` struct
export interface CharacterDied {
	character_id: BigNumberish;
	dungeon_id: BigNumberish;
	chamber_id: BigNumberish;
	killed_by: MonsterTypeEnum;
}

// Type definition for `d20::d20::models::events::CharacterMinted` struct
export interface CharacterMinted {
	character_id: BigNumberish;
	character_class: CharacterClassEnum;
	player: string;
}

// Type definition for `d20::d20::models::events::CombatResult` struct
export interface CombatResult {
	character_id: BigNumberish;
	action: CombatActionEnum;
	roll: BigNumberish;
	damage_dealt: BigNumberish;
	damage_taken: BigNumberish;
	monster_killed: boolean;
}

// Type definition for `d20::d20::models::events::LevelUp` struct
export interface LevelUp {
	character_id: BigNumberish;
	new_level: BigNumberish;
}

// Type definition for `nft_combo::erc721::erc721_combo::ERC721ComboComponent::BatchMetadataUpdate` struct
export interface BatchMetadataUpdate {
	from_token_id: BigNumberish;
	to_token_id: BigNumberish;
}

// Type definition for `nft_combo::erc721::erc721_combo::ERC721ComboComponent::MetadataUpdate` struct
export interface MetadataUpdate {
	token_id: BigNumberish;
}

// Type definition for `openzeppelin_token::erc721::erc721::ERC721Component::Approval` struct
export interface Approval {
	owner: string;
	approved: string;
	token_id: BigNumberish;
}

// Type definition for `openzeppelin_token::erc721::erc721::ERC721Component::ApprovalForAll` struct
export interface ApprovalForAll {
	owner: string;
	operator: string;
	approved: boolean;
}

// Type definition for `openzeppelin_token::erc721::erc721::ERC721Component::Transfer` struct
export interface Transfer {
	from: string;
	to: string;
	token_id: BigNumberish;
}

// Type definition for `d20::d20::models::character::Skill` enum
export const skill = [
	'None',
	'Athletics',
	'Stealth',
	'Perception',
	'Persuasion',
	'Arcana',
	'Acrobatics',
] as const;
export type Skill = { [key in typeof skill[number]]: string };
export type SkillEnum = CairoCustomEnum;

// Type definition for `d20::d20::models::monster::MonsterType` enum
export const monsterType = [
	'None',
	'PoisonousSnake',
	'Skeleton',
	'Shadow',
	'AnimatedArmor',
	'Gargoyle',
	'Mummy',
	'Wraith',
] as const;
export type MonsterType = { [key in typeof monsterType[number]]: string };
export type MonsterTypeEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::character_class::CharacterClass` enum
export const characterClass = [
	'None',
	'Fighter',
	'Rogue',
	'Wizard',
] as const;
export type CharacterClass = { [key in typeof characterClass[number]]: string };
export type CharacterClassEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::index::ChamberType` enum
export const chamberType = [
	'None',
	'Entrance',
	'Empty',
	'Monster',
	'Treasure',
	'Trap',
	'Boss',
] as const;
export type ChamberType = { [key in typeof chamberType[number]]: string };
export type ChamberTypeEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::items::ArmorType` enum
export const armorType = [
	'None',
	'Leather',
	'ChainMail',
] as const;
export type ArmorType = { [key in typeof armorType[number]]: string };
export type ArmorTypeEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::items::WeaponType` enum
export const weaponType = [
	'None',
	'Longsword',
	'Dagger',
	'Shortbow',
	'Greataxe',
	'Staff',
] as const;
export type WeaponType = { [key in typeof weaponType[number]]: string };
export type WeaponTypeEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::index::CombatAction` enum
export const combatAction = [
	'None',
	'Attack',
	'CastSpell',
	'UseItem',
	'Flee',
	'Dodge',
	'SecondWind',
	'CunningAction',
] as const;
export type CombatAction = { [key in typeof combatAction[number]]: string };
export type CombatActionEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::items::ItemType` enum
export const itemType = [
	'None',
	'HealthPotion',
] as const;
export type ItemType = { [key in typeof itemType[number]]: string };
export type ItemTypeEnum = CairoCustomEnum;

// Type definition for `d20::d20::types::spells::SpellId` enum
export const spellId = [
	'None',
	'FireBolt',
	'MageHand',
	'Light',
	'MagicMissile',
	'ShieldSpell',
	'Sleep',
	'ScorchingRay',
	'MistyStep',
	'Fireball',
] as const;
export type SpellId = { [key in typeof spellId[number]]: string };
export type SpellIdEnum = CairoCustomEnum;

export interface SchemaType extends ISchemaType {
	d20: {
		AbilityScore: AbilityScore,
		CharacterCombat: CharacterCombat,
		CharacterInventory: CharacterInventory,
		CharacterPosition: CharacterPosition,
		CharacterSkills: CharacterSkills,
		CharacterStats: CharacterStats,
		SkillsSet: SkillsSet,
		Chamber: Chamber,
		ChamberExit: ChamberExit,
		CharacterDungeonProgress: CharacterDungeonProgress,
		DungeonState: DungeonState,
		FallenCharacter: FallenCharacter,
		MonsterInstance: MonsterInstance,
		Config: Config,
		BossDefeated: BossDefeated,
		ChamberRevealed: ChamberRevealed,
		CharacterDied: CharacterDied,
		CharacterMinted: CharacterMinted,
		CombatResult: CombatResult,
		LevelUp: LevelUp,
		BatchMetadataUpdate: BatchMetadataUpdate,
		MetadataUpdate: MetadataUpdate,
		Approval: Approval,
		ApprovalForAll: ApprovalForAll,
		Transfer: Transfer,
	},
}
export const schema: SchemaType = {
	d20: {
		AbilityScore: {
			strength: 0,
			dexterity: 0,
			constitution: 0,
			intelligence: 0,
			wisdom: 0,
			charisma: 0,
		},
		CharacterCombat: {
			character_id: 0,
			armor_class: 0,
			spell_slots_1: 0,
			spell_slots_2: 0,
			spell_slots_3: 0,
			second_wind_used: false,
			action_surge_used: false,
		},
		CharacterInventory: {
			character_id: 0,
		primary_weapon: new CairoCustomEnum({ 
					None: "",
				Longsword: undefined,
				Dagger: undefined,
				Shortbow: undefined,
				Greataxe: undefined,
				Staff: undefined, }),
		secondary_weapon: new CairoCustomEnum({ 
					None: "",
				Longsword: undefined,
				Dagger: undefined,
				Shortbow: undefined,
				Greataxe: undefined,
				Staff: undefined, }),
		armor: new CairoCustomEnum({ 
					None: "",
				Leather: undefined,
				ChainMail: undefined, }),
			has_shield: false,
			gold: 0,
			potions: 0,
		},
		CharacterPosition: {
			character_id: 0,
			dungeon_id: 0,
			chamber_id: 0,
			in_combat: false,
			combat_monster_id: 0,
		},
		CharacterSkills: {
			character_id: 0,
		skills: { athletics: false, stealth: false, perception: false, persuasion: false, arcana: false, acrobatics: false, },
		expertise_1: new CairoCustomEnum({ 
					None: "",
				Athletics: undefined,
				Stealth: undefined,
				Perception: undefined,
				Persuasion: undefined,
				Arcana: undefined,
				Acrobatics: undefined, }),
		expertise_2: new CairoCustomEnum({ 
					None: "",
				Athletics: undefined,
				Stealth: undefined,
				Perception: undefined,
				Persuasion: undefined,
				Arcana: undefined,
				Acrobatics: undefined, }),
		},
		CharacterStats: {
			character_id: 0,
		abilities: { strength: 0, dexterity: 0, constitution: 0, intelligence: 0, wisdom: 0, charisma: 0, },
			level: 0,
			xp: 0,
		character_class: new CairoCustomEnum({ 
					None: "",
				Fighter: undefined,
				Rogue: undefined,
				Wizard: undefined, }),
			dungeons_conquered: 0,
			current_hp: 0,
			max_hp: 0,
			is_dead: false,
		},
		SkillsSet: {
			athletics: false,
			stealth: false,
			perception: false,
			persuasion: false,
			arcana: false,
			acrobatics: false,
		},
		Chamber: {
			dungeon_id: 0,
			chamber_id: 0,
		chamber_type: new CairoCustomEnum({ 
					None: "",
				Entrance: undefined,
				Empty: undefined,
				Monster: undefined,
				Treasure: undefined,
				Trap: undefined,
				Boss: undefined, }),
			depth: 0,
			exit_count: 0,
			is_revealed: false,
			treasure_looted: false,
			trap_disarmed: false,
			trap_dc: 0,
			fallen_count: 0,
		},
		ChamberExit: {
			dungeon_id: 0,
			from_chamber_id: 0,
			exit_index: 0,
			to_chamber_id: 0,
			is_discovered: false,
		},
		CharacterDungeonProgress: {
			character_id: 0,
			dungeon_id: 0,
			chambers_explored: 0,
			xp_earned: 0,
		},
		DungeonState: {
			dungeon_id: 0,
			difficulty_tier: 0,
			next_chamber_id: 0,
			boss_chamber_id: 0,
			boss_alive: false,
			max_depth: 0,
		},
		FallenCharacter: {
			dungeon_id: 0,
			chamber_id: 0,
			fallen_index: 0,
			character_id: 0,
		dropped_weapon: new CairoCustomEnum({ 
					None: "",
				Longsword: undefined,
				Dagger: undefined,
				Shortbow: undefined,
				Greataxe: undefined,
				Staff: undefined, }),
		dropped_armor: new CairoCustomEnum({ 
					None: "",
				Leather: undefined,
				ChainMail: undefined, }),
			dropped_gold: 0,
			dropped_potions: 0,
			is_looted: false,
		},
		MonsterInstance: {
			dungeon_id: 0,
			chamber_id: 0,
			monster_id: 0,
		monster_type: new CairoCustomEnum({ 
					None: "",
				PoisonousSnake: undefined,
				Skeleton: undefined,
				Shadow: undefined,
				AnimatedArmor: undefined,
				Gargoyle: undefined,
				Mummy: undefined,
				Wraith: undefined, }),
			current_hp: 0,
			max_hp: 0,
			is_alive: false,
		},
		Config: {
			key: 0,
			vrf_address: "",
		},
		BossDefeated: {
			dungeon_id: 0,
			character_id: 0,
		monster_type: new CairoCustomEnum({ 
					None: "",
				PoisonousSnake: undefined,
				Skeleton: undefined,
				Shadow: undefined,
				AnimatedArmor: undefined,
				Gargoyle: undefined,
				Mummy: undefined,
				Wraith: undefined, }),
		},
		ChamberRevealed: {
			dungeon_id: 0,
			chamber_id: 0,
		chamber_type: new CairoCustomEnum({ 
					None: "",
				Entrance: undefined,
				Empty: undefined,
				Monster: undefined,
				Treasure: undefined,
				Trap: undefined,
				Boss: undefined, }),
			depth: 0,
			revealed_by: 0,
		},
		CharacterDied: {
			character_id: 0,
			dungeon_id: 0,
			chamber_id: 0,
		killed_by: new CairoCustomEnum({ 
					None: "",
				PoisonousSnake: undefined,
				Skeleton: undefined,
				Shadow: undefined,
				AnimatedArmor: undefined,
				Gargoyle: undefined,
				Mummy: undefined,
				Wraith: undefined, }),
		},
		CharacterMinted: {
			character_id: 0,
		character_class: new CairoCustomEnum({ 
					None: "",
				Fighter: undefined,
				Rogue: undefined,
				Wizard: undefined, }),
			player: "",
		},
		CombatResult: {
			character_id: 0,
		action: new CairoCustomEnum({ 
					None: "",
				Attack: undefined,
				CastSpell: undefined,
				UseItem: undefined,
				Flee: undefined,
				Dodge: undefined,
				SecondWind: undefined,
				CunningAction: undefined, }),
			roll: 0,
			damage_dealt: 0,
			damage_taken: 0,
			monster_killed: false,
		},
		LevelUp: {
			character_id: 0,
			new_level: 0,
		},
		BatchMetadataUpdate: {
		from_token_id: 0,
		to_token_id: 0,
		},
		MetadataUpdate: {
		token_id: 0,
		},
		Approval: {
			owner: "",
			approved: "",
		token_id: 0,
		},
		ApprovalForAll: {
			owner: "",
			operator: "",
			approved: false,
		},
		Transfer: {
			from: "",
			to: "",
		token_id: 0,
		},
	},
};
export enum ModelsMapping {
	AbilityScore = 'd20-AbilityScore',
	CharacterCombat = 'd20-CharacterCombat',
	CharacterInventory = 'd20-CharacterInventory',
	CharacterPosition = 'd20-CharacterPosition',
	CharacterSkills = 'd20-CharacterSkills',
	CharacterStats = 'd20-CharacterStats',
	Skill = 'd20-Skill',
	SkillsSet = 'd20-SkillsSet',
	Chamber = 'd20-Chamber',
	ChamberExit = 'd20-ChamberExit',
	CharacterDungeonProgress = 'd20-CharacterDungeonProgress',
	DungeonState = 'd20-DungeonState',
	FallenCharacter = 'd20-FallenCharacter',
	MonsterInstance = 'd20-MonsterInstance',
	MonsterType = 'd20-MonsterType',
	CharacterClass = 'd20-CharacterClass',
	ChamberType = 'd20-ChamberType',
	ArmorType = 'd20-ArmorType',
	WeaponType = 'd20-WeaponType',
	Config = 'd20-Config',
	BossDefeated = 'd20-BossDefeated',
	ChamberRevealed = 'd20-ChamberRevealed',
	CharacterDied = 'd20-CharacterDied',
	CharacterMinted = 'd20-CharacterMinted',
	CombatResult = 'd20-CombatResult',
	LevelUp = 'd20-LevelUp',
	CombatAction = 'd20-CombatAction',
	ItemType = 'd20-ItemType',
	SpellId = 'd20-SpellId',
	BatchMetadataUpdate = 'nft_combo-BatchMetadataUpdate',
	ContractURIUpdated = 'nft_combo-ContractURIUpdated',
	MetadataUpdate = 'nft_combo-MetadataUpdate',
	Approval = 'openzeppelin_token-Approval',
	ApprovalForAll = 'openzeppelin_token-ApprovalForAll',
	Transfer = 'openzeppelin_token-Transfer',
}