import type { SchemaType as ISchemaType } from "@dojoengine/sdk";

import { CairoCustomEnum, BigNumberish } from 'starknet';

// Type definition for `d20::models::config::Config` struct
export interface Config {
	key: BigNumberish;
	vrf_address: string;
}

// Type definition for `d20::d20::models::adventurer::AbilityScore` struct
export interface AbilityScore {
	strength: BigNumberish;
	dexterity: BigNumberish;
	constitution: BigNumberish;
	intelligence: BigNumberish;
	wisdom: BigNumberish;
	charisma: BigNumberish;
}

// Type definition for `d20::d20::models::adventurer::ExplorerCombat` struct
export interface ExplorerCombat {
	adventurer_id: BigNumberish;
	armor_class: BigNumberish;
	spell_slots_1: BigNumberish;
	spell_slots_2: BigNumberish;
	spell_slots_3: BigNumberish;
	second_wind_used: boolean;
	action_surge_used: boolean;
}

// Type definition for `d20::d20::models::adventurer::ExplorerHealth` struct
export interface ExplorerHealth {
	adventurer_id: BigNumberish;
	current_hp: BigNumberish;
	max_hp: BigNumberish;
	is_dead: boolean;
}

// Type definition for `d20::d20::models::adventurer::ExplorerInventory` struct
export interface ExplorerInventory {
	adventurer_id: BigNumberish;
	primary_weapon: WeaponTypeEnum;
	secondary_weapon: WeaponTypeEnum;
	armor: ArmorTypeEnum;
	has_shield: boolean;
	gold: BigNumberish;
	potions: BigNumberish;
}

// Type definition for `d20::d20::models::adventurer::ExplorerPosition` struct
export interface ExplorerPosition {
	adventurer_id: BigNumberish;
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	in_combat: boolean;
	combat_monster_id: BigNumberish;
}

// Type definition for `d20::d20::models::adventurer::ExplorerSkills` struct
export interface ExplorerSkills {
	adventurer_id: BigNumberish;
	skills: SkillsSet;
	expertise_1: SkillEnum;
	expertise_2: SkillEnum;
}

// Type definition for `d20::d20::models::adventurer::ExplorerStats` struct
export interface ExplorerStats {
	adventurer_id: BigNumberish;
	abilities: AbilityScore;
	level: BigNumberish;
	xp: BigNumberish;
	adventurer_class: AdventurerClassEnum;
	temples_conquered: BigNumberish;
}

// Type definition for `d20::d20::models::adventurer::SkillsSet` struct
export interface SkillsSet {
	athletics: boolean;
	stealth: boolean;
	perception: boolean;
	persuasion: boolean;
	arcana: boolean;
	acrobatics: boolean;
}

// Type definition for `d20::models::temple::Chamber` struct
export interface Chamber {
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	chamber_type: ChamberTypeEnum;
	yonder: BigNumberish;
	exit_count: BigNumberish;
	is_revealed: boolean;
	treasure_looted: boolean;
	trap_disarmed: boolean;
	trap_dc: BigNumberish;
}

// Type definition for `d20::models::temple::ChamberExit` struct
export interface ChamberExit {
	temple_id: BigNumberish;
	from_chamber_id: BigNumberish;
	exit_index: BigNumberish;
	to_chamber_id: BigNumberish;
	is_discovered: boolean;
}

// Type definition for `d20::models::temple::ChamberFallenCount` struct
export interface ChamberFallenCount {
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	count: BigNumberish;
}

// Type definition for `d20::models::temple::ExplorerTempleProgress` struct
export interface ExplorerTempleProgress {
	adventurer_id: BigNumberish;
	temple_id: BigNumberish;
	chambers_explored: BigNumberish;
	xp_earned: BigNumberish;
}

// Type definition for `d20::models::temple::FallenExplorer` struct
export interface FallenExplorer {
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	fallen_index: BigNumberish;
	adventurer_id: BigNumberish;
	dropped_weapon: WeaponTypeEnum;
	dropped_armor: ArmorTypeEnum;
	dropped_gold: BigNumberish;
	dropped_potions: BigNumberish;
	is_looted: boolean;
}

// Type definition for `d20::models::temple::MonsterInstance` struct
export interface MonsterInstance {
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	monster_id: BigNumberish;
	monster_type: MonsterTypeEnum;
	current_hp: BigNumberish;
	max_hp: BigNumberish;
	is_alive: boolean;
}

// Type definition for `d20::models::temple::TempleState` struct
export interface TempleState {
	temple_id: BigNumberish;
	difficulty_tier: BigNumberish;
	next_chamber_id: BigNumberish;
	boss_chamber_id: BigNumberish;
	boss_alive: boolean;
	max_yonder: BigNumberish;
}

// Type definition for `d20::events::BossDefeated` struct
export interface BossDefeated {
	temple_id: BigNumberish;
	adventurer_id: BigNumberish;
	monster_type: MonsterTypeEnum;
}

// Type definition for `d20::events::ChamberRevealed` struct
export interface ChamberRevealed {
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	chamber_type: ChamberTypeEnum;
	yonder: BigNumberish;
	revealed_by: BigNumberish;
}

// Type definition for `d20::events::CombatResult` struct
export interface CombatResult {
	adventurer_id: BigNumberish;
	action: CombatActionEnum;
	roll: BigNumberish;
	damage_dealt: BigNumberish;
	damage_taken: BigNumberish;
	monster_killed: boolean;
}

// Type definition for `d20::events::ExplorerDied` struct
export interface ExplorerDied {
	adventurer_id: BigNumberish;
	temple_id: BigNumberish;
	chamber_id: BigNumberish;
	killed_by: MonsterTypeEnum;
}

// Type definition for `d20::events::ExplorerMinted` struct
export interface ExplorerMinted {
	adventurer_id: BigNumberish;
	adventurer_class: AdventurerClassEnum;
	player: string;
}

// Type definition for `d20::events::LevelUp` struct
export interface LevelUp {
	adventurer_id: BigNumberish;
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

// Type definition for `d20::d20::types::adventurer_class::AdventurerClass` enum
export const explorerClass = [
	'None',
	'Fighter',
	'Rogue',
	'Wizard',
] as const;
export type AdventurerClass = { [key in typeof explorerClass[number]]: string };
export type AdventurerClassEnum = CairoCustomEnum;

// Type definition for `d20::types::index::ChamberType` enum
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

// Type definition for `d20::types::index::Skill` enum
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

// Type definition for `d20::types::items::ArmorType` enum
export const armorType = [
	'None',
	'Leather',
	'ChainMail',
] as const;
export type ArmorType = { [key in typeof armorType[number]]: string };
export type ArmorTypeEnum = CairoCustomEnum;

// Type definition for `d20::types::items::WeaponType` enum
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

// Type definition for `d20::types::monster::MonsterType` enum
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

// Type definition for `d20::types::index::CombatAction` enum
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

// Type definition for `d20::types::index::ItemType` enum
export const itemType = [
	'None',
	'HealthPotion',
] as const;
export type ItemType = { [key in typeof itemType[number]]: string };
export type ItemTypeEnum = CairoCustomEnum;

// Type definition for `d20::types::spells::SpellId` enum
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
		Config: Config,
		AbilityScore: AbilityScore,
		ExplorerCombat: ExplorerCombat,
		ExplorerHealth: ExplorerHealth,
		ExplorerInventory: ExplorerInventory,
		ExplorerPosition: ExplorerPosition,
		ExplorerSkills: ExplorerSkills,
		ExplorerStats: ExplorerStats,
		SkillsSet: SkillsSet,
		Chamber: Chamber,
		ChamberExit: ChamberExit,
		ChamberFallenCount: ChamberFallenCount,
		ExplorerTempleProgress: ExplorerTempleProgress,
		FallenExplorer: FallenExplorer,
		MonsterInstance: MonsterInstance,
		TempleState: TempleState,
		BossDefeated: BossDefeated,
		ChamberRevealed: ChamberRevealed,
		CombatResult: CombatResult,
		ExplorerDied: ExplorerDied,
		ExplorerMinted: ExplorerMinted,
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
		Config: {
			key: 0,
			vrf_address: "",
		},
		AbilityScore: {
			strength: 0,
			dexterity: 0,
			constitution: 0,
			intelligence: 0,
			wisdom: 0,
			charisma: 0,
		},
		ExplorerCombat: {
			adventurer_id: 0,
			armor_class: 0,
			spell_slots_1: 0,
			spell_slots_2: 0,
			spell_slots_3: 0,
			second_wind_used: false,
			action_surge_used: false,
		},
		ExplorerHealth: {
			adventurer_id: 0,
			current_hp: 0,
			max_hp: 0,
			is_dead: false,
		},
		ExplorerInventory: {
			adventurer_id: 0,
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
		ExplorerPosition: {
			adventurer_id: 0,
			temple_id: 0,
			chamber_id: 0,
			in_combat: false,
			combat_monster_id: 0,
		},
		ExplorerSkills: {
			adventurer_id: 0,
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
		ExplorerStats: {
			adventurer_id: 0,
		abilities: { strength: 0, dexterity: 0, constitution: 0, intelligence: 0, wisdom: 0, charisma: 0, },
			level: 0,
			xp: 0,
		adventurer_class: new CairoCustomEnum({ 
					None: "",
				Fighter: undefined,
				Rogue: undefined,
				Wizard: undefined, }),
			temples_conquered: 0,
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
			temple_id: 0,
			chamber_id: 0,
		chamber_type: new CairoCustomEnum({ 
					None: "",
				Entrance: undefined,
				Empty: undefined,
				Monster: undefined,
				Treasure: undefined,
				Trap: undefined,
				Boss: undefined, }),
			yonder: 0,
			exit_count: 0,
			is_revealed: false,
			treasure_looted: false,
			trap_disarmed: false,
			trap_dc: 0,
		},
		ChamberExit: {
			temple_id: 0,
			from_chamber_id: 0,
			exit_index: 0,
			to_chamber_id: 0,
			is_discovered: false,
		},
		ChamberFallenCount: {
			temple_id: 0,
			chamber_id: 0,
			count: 0,
		},
		ExplorerTempleProgress: {
			adventurer_id: 0,
			temple_id: 0,
			chambers_explored: 0,
			xp_earned: 0,
		},
		FallenExplorer: {
			temple_id: 0,
			chamber_id: 0,
			fallen_index: 0,
			adventurer_id: 0,
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
			temple_id: 0,
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
		TempleState: {
			temple_id: 0,
			difficulty_tier: 0,
			next_chamber_id: 0,
			boss_chamber_id: 0,
			boss_alive: false,
			max_yonder: 0,
		},
		BossDefeated: {
			temple_id: 0,
			adventurer_id: 0,
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
			temple_id: 0,
			chamber_id: 0,
		chamber_type: new CairoCustomEnum({ 
					None: "",
				Entrance: undefined,
				Empty: undefined,
				Monster: undefined,
				Treasure: undefined,
				Trap: undefined,
				Boss: undefined, }),
			yonder: 0,
			revealed_by: 0,
		},
		CombatResult: {
			adventurer_id: 0,
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
		ExplorerDied: {
			adventurer_id: 0,
			temple_id: 0,
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
		ExplorerMinted: {
			adventurer_id: 0,
		adventurer_class: new CairoCustomEnum({ 
					None: "",
				Fighter: undefined,
				Rogue: undefined,
				Wizard: undefined, }),
			player: "",
		},
		LevelUp: {
			adventurer_id: 0,
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
	Config = 'd20-Config',
	AbilityScore = 'd20-AbilityScore',
	ExplorerCombat = 'd20-ExplorerCombat',
	ExplorerHealth = 'd20-ExplorerHealth',
	ExplorerInventory = 'd20-ExplorerInventory',
	ExplorerPosition = 'd20-ExplorerPosition',
	ExplorerSkills = 'd20-ExplorerSkills',
	ExplorerStats = 'd20-ExplorerStats',
	SkillsSet = 'd20-SkillsSet',
	Chamber = 'd20-Chamber',
	ChamberExit = 'd20-ChamberExit',
	ChamberFallenCount = 'd20-ChamberFallenCount',
	ExplorerTempleProgress = 'd20-ExplorerTempleProgress',
	FallenExplorer = 'd20-FallenExplorer',
	MonsterInstance = 'd20-MonsterInstance',
	TempleState = 'd20-TempleState',
	AdventurerClass = 'd20-AdventurerClass',
	ChamberType = 'd20-ChamberType',
	Skill = 'd20-Skill',
	ArmorType = 'd20-ArmorType',
	WeaponType = 'd20-WeaponType',
	MonsterType = 'd20-MonsterType',
	BossDefeated = 'd20-BossDefeated',
	ChamberRevealed = 'd20-ChamberRevealed',
	CombatResult = 'd20-CombatResult',
	ExplorerDied = 'd20-ExplorerDied',
	ExplorerMinted = 'd20-ExplorerMinted',
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