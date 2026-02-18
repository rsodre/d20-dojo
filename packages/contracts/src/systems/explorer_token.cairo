

// ── Public interface ────────────────────────────────────────────────────────

use crate::types::explorer::ExplorerClass;
use crate::types::index::Skill;

#[starknet::interface]
pub trait IExplorerToken<TState> {
    /// Mint a new Explorer NFT.
    ///
    /// Parameters:
    /// - `class`: Fighter, Rogue, or Wizard
    /// - `stat_assignment`: 6 values assigned to [STR, DEX, CON, INT, WIS, CHA]
    ///   Must be a permutation of [15, 14, 13, 12, 10, 8] (standard array).
    /// - `skill_choices`: class-specific optional skill picks
    /// - `expertise_choices`: Rogue only — 2 skills for double proficiency (Expertise)
    ///
    /// Returns the new explorer's token ID (u256, ERC-721 standard).
    fn mint_explorer(
        ref self: TState,
        class: ExplorerClass,
        stat_assignment: Span<u8>,
        skill_choices: Span<Skill>,
        expertise_choices: Span<Skill>,
    ) -> u256;

    /// Restore HP to max, reset spell slots to class/level values,
    /// and reset `second_wind_used` / `action_surge_used`.
    fn rest(ref self: TState, explorer_id: u128);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod explorer_token {
    use super::IExplorerToken;
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use dojo::world::WorldStorage;

    // ERC-721 components (OpenZeppelin + cairo-nft-combo)
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use nft_combo::erc721::erc721_combo::ERC721ComboComponent;
    use nft_combo::erc721::erc721_combo::ERC721ComboComponent::ERC721HooksImpl;
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721ComboComponent, storage: erc721_combo, event: ERC721ComboEvent);
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl ERC721ComboInternalImpl = ERC721ComboComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721ComboMixinImpl = ERC721ComboComponent::ERC721ComboMixinImpl<ContractState>;

    // Game types and models
    use d20::types::index::Skill;
    use d20::types::explorer::{ExplorerClass, ExplorerClassTrait};
    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills,
    };
    use d20::events::ExplorerMinted;
    use d20::utils::dice::{ability_modifier, calculate_ac};
    use d20::constants::{EXPLORER_TOKEN_DESCRIPTION, EXPLORER_TOKEN_EXTERNAL_LINK};

    // Metadata types
    use nft_combo::utils::renderer::{ContractMetadata, TokenMetadata, Attribute};

    // ── Storage ─────────────────────────────────────────────────────────────

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_combo: ERC721ComboComponent::Storage,
    }

    // ── Events ───────────────────────────────────────────────────────────────

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721ComboEvent: ERC721ComboComponent::Event,
    }

    // ── Token defaults ───────────────────────────────────────────────────────

    pub fn TOKEN_NAME() -> ByteArray { "D20 Explorer" }
    pub fn TOKEN_SYMBOL() -> ByteArray { "EXPLORER" }

    // ── Initializer ──────────────────────────────────────────────────────────

    fn dojo_init(ref self: ContractState) {
        self.erc721_combo.initializer(
            TOKEN_NAME(),
            TOKEN_SYMBOL(),
            Option::None, // base_uri: use hooks for on-chain metadata
            Option::None, // contract_uri: use hooks
            Option::None, // max_supply: unlimited
        );
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"d20_0_1")
        }
    }

    // ── Standard array validation ────────────────────────────────────────────

    fn validate_standard_array(stat_assignment: Span<u8>) {
        assert(stat_assignment.len() == 6, 'need exactly 6 stats');
        let mut count_8: u8 = 0;
        let mut count_10: u8 = 0;
        let mut count_12: u8 = 0;
        let mut count_13: u8 = 0;
        let mut count_14: u8 = 0;
        let mut count_15: u8 = 0;
        let mut i: u32 = 0;
        while i < stat_assignment.len() {
            let v = *stat_assignment.at(i);
            if v == 8 { count_8 += 1; }
            else if v == 10 { count_10 += 1; }
            else if v == 12 { count_12 += 1; }
            else if v == 13 { count_13 += 1; }
            else if v == 14 { count_14 += 1; }
            else if v == 15 { count_15 += 1; }
            else { assert(false, 'not standard array'); }
            i += 1;
        };
        assert(
            count_8 == 1 && count_10 == 1 && count_12 == 1
                && count_13 == 1 && count_14 == 1 && count_15 == 1,
            'not standard array'
        );
    }

    // ── Spell slots by class and level ───────────────────────────────────────



    fn get_expertise(expertise_choices: Span<Skill>) -> (Skill, Skill) {
        if expertise_choices.len() == 2 {
            (*expertise_choices.at(0), *expertise_choices.at(1))
        } else {
            (Skill::None, Skill::None)
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl ExplorerTokenImpl of IExplorerToken<ContractState> {
        fn mint_explorer(
            ref self: ContractState,
            class: ExplorerClass,
            stat_assignment: Span<u8>,
            skill_choices: Span<Skill>,
            expertise_choices: Span<Skill>,
        ) -> u256 {
            assert(class != ExplorerClass::None, 'must choose a class');

            validate_standard_array(stat_assignment);
            class.validate_skill_choices(skill_choices);
            class.validate_expertise(expertise_choices, skill_choices);

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let explorer_id: u128 = token_id.low;

            // Unpack stats [STR, DEX, CON, INT, WIS, CHA]
            let strength: u8 = *stat_assignment.at(0);
            let dexterity: u8 = *stat_assignment.at(1);
            let constitution: u8 = *stat_assignment.at(2);
            let intelligence: u8 = *stat_assignment.at(3);
            let wisdom: u8 = *stat_assignment.at(4);
            let charisma: u8 = *stat_assignment.at(5);

            let con_mod: i8 = ability_modifier(constitution);
            let dex_mod: i8 = ability_modifier(dexterity);

            // Starting HP: hit die max + CON modifier (minimum 1)
            let hit_die = class.hit_die_max();
            let raw_hp: i16 = hit_die.into() + con_mod.into();
            let max_hp: u16 = if raw_hp < 1 { 1 } else { raw_hp.try_into().unwrap() };

            // Starting equipment and AC by class
            // Starting equipment and AC by class
            let (primary_weapon, secondary_weapon, armor, has_shield) = class.starting_equipment();
            let armor_class = calculate_ac(armor, has_shield, dex_mod);

            // Spell slots (level 1)
            let (slots_1, slots_2, slots_3) = class.spell_slots_for(1);

            // Skills
            let (athletics, stealth, perception, persuasion, arcana, acrobatics) =
                class.build_skills(skill_choices);

            // Expertise (Rogue only)
            let (expertise_1, expertise_2) = get_expertise(expertise_choices);

            // Write all explorer Dojo models
            world.write_model(@ExplorerStats {
                explorer_id,
                strength, dexterity, constitution, intelligence, wisdom, charisma,
                level: 1,
                xp: 0,
                class,
                temples_conquered: 0,
            });

            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: max_hp.try_into().unwrap(),
                max_hp,
                is_dead: false,
            });

            world.write_model(@ExplorerCombat {
                explorer_id,
                armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });

            world.write_model(@ExplorerInventory {
                explorer_id,
                primary_weapon,
                secondary_weapon,
                armor,
                has_shield,
                gold: 0,
                potions: 0,
            });

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.write_model(@ExplorerSkills {
                explorer_id,
                athletics, stealth, perception, persuasion, arcana, acrobatics,
                expertise_1,
                expertise_2,
            });

            // Emit Dojo event
            world.emit_event(@ExplorerMinted {
                explorer_id,
                class,
                player: caller,
            });

            token_id
        }

        fn rest(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.class != ExplorerClass::None, 'explorer does not exist');

            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot rest');

            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: health.max_hp.try_into().unwrap(),
                max_hp: health.max_hp,
                is_dead: false,
            });

            let (slots_1, slots_2, slots_3) = stats.class.spell_slots_for(stats.level);
            let combat: ExplorerCombat = world.read_model(explorer_id);
            world.write_model(@ExplorerCombat {
                explorer_id,
                armor_class: combat.armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });
        }
    }

    // ── ERC721ComboHooksTrait ────────────────────────────────────────────────

    pub impl ERC721ComboHooksImpl of ERC721ComboComponent::ERC721ComboHooksTrait<ContractState> {
        fn render_contract_uri(
            self: @ERC721ComboComponent::ComponentState<ContractState>
        ) -> Option<ContractMetadata> {
            let s = self.get_contract();
            let metadata = ContractMetadata {
                name: s.name(),
                symbol: s.symbol(),
                description: EXPLORER_TOKEN_DESCRIPTION(),
                image: Option::None,
                banner_image: Option::None,
                featured_image: Option::None,
                external_link: Option::Some(EXPLORER_TOKEN_EXTERNAL_LINK()),
                collaborators: Option::None,
                background_color: Option::None,
            };
            Option::Some(metadata)
        }

        fn render_token_uri(
            self: @ERC721ComboComponent::ComponentState<ContractState>,
            token_id: u256,
        ) -> Option<TokenMetadata> {
            let s = self.get_contract();
            let mut world = s.world_default();
            let explorer_id: u128 = token_id.low;

            let stats: ExplorerStats = world.read_model(explorer_id);
            let health: ExplorerHealth = world.read_model(explorer_id);
            let combat: ExplorerCombat = world.read_model(explorer_id);

            let class_name: ByteArray = match stats.class {
                ExplorerClass::None => "None",
                ExplorerClass::Fighter => "Fighter",
                ExplorerClass::Rogue => "Rogue",
                ExplorerClass::Wizard => "Wizard",
            };

            let status: ByteArray = if health.is_dead { "Dead" } else { "Alive" };

            let attributes: Array<Attribute> = array![
                Attribute { key: "Class", value: class_name.clone() },
                Attribute { key: "Level", value: format!("{}", stats.level) },
                Attribute { key: "HP", value: format!("{}/{}", health.current_hp, health.max_hp) },
                Attribute { key: "AC", value: format!("{}", combat.armor_class) },
                Attribute { key: "STR", value: format!("{}", stats.strength) },
                Attribute { key: "DEX", value: format!("{}", stats.dexterity) },
                Attribute { key: "CON", value: format!("{}", stats.constitution) },
                Attribute { key: "INT", value: format!("{}", stats.intelligence) },
                Attribute { key: "WIS", value: format!("{}", stats.wisdom) },
                Attribute { key: "CHA", value: format!("{}", stats.charisma) },
                Attribute { key: "Status", value: status },
            ];

            let metadata = TokenMetadata {
                token_id,
                name: format!("{} #{}", class_name, token_id.low),
                description: EXPLORER_TOKEN_DESCRIPTION(),
                image: Option::None,
                image_data: Option::None,
                external_url: Option::None,
                background_color: Option::None,
                animation_url: Option::None,
                youtube_url: Option::None,
                attributes: Option::Some(attributes.span()),
                additional_metadata: Option::None,
            };
            Option::Some(metadata)
        }
    }
}
