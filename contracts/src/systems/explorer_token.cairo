
// ── Public interface ────────────────────────────────────────────────────────

use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use crate::types::explorer_class::ExplorerClass;

#[starknet::interface]
pub trait IExplorerToken<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    //-----------------------------------
    // IERC721ComboABI start
    //
    // (ISRC5)
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
    // (IERC721)
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>);
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    // (IERC721Metadata)
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray;
    //-----------------------------------
    // IERC721Minter
    fn max_supply(self: @TState) -> u256;
    fn total_supply(self: @TState) -> u256;
    fn last_token_id(self: @TState) -> u256;
    fn is_minting_paused(self: @TState) -> bool;
    fn is_owner_of(self: @TState, address: ContractAddress, token_id: u256) -> bool;
    fn token_exists(self: @TState, token_id: u256) -> bool;
    fn totalSupply(self: @TState) -> u256;
    //-----------------------------------
    // IERC7572ContractMetadata
    fn contract_uri(self: @TState) -> ByteArray;
    fn contractURI(self: @TState) -> ByteArray;
    //-----------------------------------
    // IERC4906MetadataUpdate
    //-----------------------------------
    // IERC2981RoyaltyInfo
    fn royalty_info(self: @TState, token_id: u256, sale_price: u256) -> (ContractAddress, u256);
    fn default_royalty(self: @TState) -> (ContractAddress, u128, u128);
    fn token_royalty(self: @TState, token_id: u256) -> (ContractAddress, u128, u128);
    // IERC721ComboABI end
    //-----------------------------------

    // IExplorerTokenPublic
    fn mint_explorer(ref self: TState, explorer_class: ExplorerClass) -> u128;
    fn rest(ref self: TState, explorer_id: u128);
}

#[starknet::interface]
pub trait IExplorerTokenPublic<TState> {
    /// Mint a new Explorer NFT.
    ///
    /// Parameters:
    /// - `class`: Fighter, Rogue, or Wizard
    ///
    /// Stats ([STR, DEX, CON, INT, WIS, CHA]) are randomly assigned from the standard array
    /// [15, 14, 13, 12, 10, 8] using VRF, biased towards the class's preferred ability scores.
    /// Skills and expertise are also randomly selected via VRF from the valid options for
    /// the chosen class.
    ///
    /// This call MUST be preceded by `request_random` on the VRF contract (multicall).
    ///
    /// Returns the new explorer's token ID (u128).
    fn mint_explorer(ref self: TState, explorer_class: ExplorerClass) -> u128;

    /// Restore HP to max, reset spell slots to class/level values,
    /// and reset `second_wind_used` / `action_surge_used`.
    fn rest(ref self: TState, explorer_id: u128);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod explorer_token {
    use starknet::{get_caller_address, ContractAddress};
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

    // D20 character component
    use d20::d20::components::character_component::CharacterComponent;
    component!(path: CharacterComponent, storage: character, event: CharacterEvent);
    #[abi(embed_v0)]
    impl CharacterImpl = CharacterComponent::CharacterImpl<ContractState>;

    // Game types and models
    use d20::types::explorer_class::{ExplorerClass, ExplorerClassTrait};
    use d20::models::explorer::{
        ExplorerStats, ExplorerHealth, ExplorerCombat, ExplorerInventory,
        ExplorerPosition, ExplorerSkills,
    };
    use d20::models::config::Config;
    use d20::utils::dns::{DnsTrait};
    use super::{IExplorerTokenDispatcherTrait};
    use d20::events::ExplorerMinted;
    use d20::utils::dice::{ability_modifier, calculate_ac};
    use d20::utils::seeder::{SeederTrait};
    use d20::types::explorer_generator::ExplorerClassGeneratorTrait;
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
        #[substorage(v0)]
        character: CharacterComponent::Storage,
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
        CharacterEvent: CharacterComponent::Event,
    }

    // ── Token defaults ───────────────────────────────────────────────────────

    pub fn TOKEN_NAME() -> ByteArray { "D20 Explorer" }
    pub fn TOKEN_SYMBOL() -> ByteArray { "EXPLORER" }

    // ── Initializer ──────────────────────────────────────────────────────────

    fn dojo_init(ref self: ContractState, vrf_address: ContractAddress) {
        self.erc721_combo.initializer(
            TOKEN_NAME(),
            TOKEN_SYMBOL(),
            Option::None, // base_uri: use hooks for on-chain metadata
            Option::None, // contract_uri: use hooks
            Option::None, // max_supply: unlimited
        );
        let mut world = self.world_default();
        world.write_model(@Config { key: 1, vrf_address });
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"d20_0_1")
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl ExplorerTokenPublicImpl of super::IExplorerTokenPublic<ContractState> {
        fn mint_explorer(ref self: ContractState, explorer_class: ExplorerClass) -> u128 {
            assert(explorer_class != ExplorerClass::None, 'must choose a class');

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Consume VRF for all randomization (must be preceded by request_random multicall)
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let explorer_id: u128 = token_id.low;

            // Randomly assign stats from standard array [15,14,13,12,10,8] using VRF
            let abilities = explorer_class.random_stat_assignment(ref seeder);

            let con_mod: i8 = ability_modifier(abilities.constitution);
            let dex_mod: i8 = ability_modifier(abilities.dexterity);

            // Starting HP: hit die max + CON modifier (minimum 1)
            let hit_die = explorer_class.hit_die_max();
            let raw_hp: i16 = hit_die.into() + con_mod.into();
            let max_hp: u16 = if raw_hp < 1 { 1 } else { raw_hp.try_into().unwrap() };

            // Starting equipment and AC by class
            let (primary_weapon, secondary_weapon, armor, has_shield) = explorer_class.starting_equipment();
            let armor_class = calculate_ac(armor, has_shield, dex_mod);

            // Spell slots (level 1)
            let (slots_1, slots_2, slots_3) = explorer_class.spell_slots_for(1);

            // Randomly pick skills from VRF
            let (skills, expertise_1, expertise_2) = explorer_class.random_skills(ref seeder);

            // Write all explorer Dojo models
            world.write_model(@ExplorerStats {
                explorer_id,
                abilities,
                level: 1,
                xp: 0,
                explorer_class,
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
                skills,
                expertise_1,
                expertise_2,
            });

            // Emit Dojo event
            world.emit_event(@ExplorerMinted {
                explorer_id,
                explorer_class,
                player: caller,
            });

            explorer_id
        }

        fn rest(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == get_caller_address(), 'not owner');

            let stats: ExplorerStats = world.read_model(explorer_id);
            assert(stats.explorer_class != ExplorerClass::None, 'explorer does not exist');

            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot rest');

            world.write_model(@ExplorerHealth {
                explorer_id,
                current_hp: health.max_hp.try_into().unwrap(),
                max_hp: health.max_hp,
                is_dead: false,
            });

            let (slots_1, slots_2, slots_3) = stats.explorer_class.spell_slots_for(stats.level);
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

            let class_name: ByteArray = match stats.explorer_class {
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
                Attribute { key: "STR", value: format!("{}", stats.abilities.strength) },
                Attribute { key: "DEX", value: format!("{}", stats.abilities.dexterity) },
                Attribute { key: "CON", value: format!("{}", stats.abilities.constitution) },
                Attribute { key: "INT", value: format!("{}", stats.abilities.intelligence) },
                Attribute { key: "WIS", value: format!("{}", stats.abilities.wisdom) },
                Attribute { key: "CHA", value: format!("{}", stats.abilities.charisma) },
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
