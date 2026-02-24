
// ── Public interface ────────────────────────────────────────────────────────

use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use d20::d20::types::character_class::CharacterClass;

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
    fn mint_explorer(ref self: TState, character_class: CharacterClass) -> u128;
    fn rest(ref self: TState, character_id: u128);
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
    fn mint_explorer(ref self: TState, character_class: CharacterClass) -> u128;

    /// Restore HP to max, reset spell slots to class/level values,
    /// and reset `second_wind_used` / `action_surge_used`.
    fn rest(ref self: TState, character_id: u128);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod explorer_token {
    use starknet::{get_caller_address, ContractAddress};
    use dojo::model::ModelStorage;
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
    impl CharacterInternalImpl = CharacterComponent::InternalImpl<ContractState>;

    // Game types and models
    use d20::d20::types::character_class::CharacterClass;
    use d20::d20::types::attributes::CharacterAttributes;
    use d20::models::config::Config;
    use d20::utils::dns::{DnsTrait};
    use super::{IExplorerTokenDispatcherTrait};
    use d20::utils::seeder::{SeederTrait};
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
            self.world(@"d20_0_2")
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl ExplorerTokenPublicImpl of super::IExplorerTokenPublic<ContractState> {
        fn mint_explorer(ref self: ContractState, character_class: CharacterClass) -> u128 {
            assert(character_class != CharacterClass::None, 'must choose a class');

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Consume VRF for all randomization (must be preceded by request_random multicall)
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let character_id: u128 = token_id.low;

            self.character.generate_character(ref world, character_id, character_class, caller, ref seeder);

            character_id
        }

        fn rest(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == get_caller_address(), 'not owner');

            self.character.rest(ref world, character_id);
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
            let character_id: u128 = token_id.low;

            let char_attrs: CharacterAttributes = s.character.get_attributes(ref world, character_id);
            let attributes: Array<Attribute> = array![
                Attribute { key: "Class", value: char_attrs.character_class.clone() },
                Attribute { key: "Level", value: format!("{}", char_attrs.level) },
                Attribute { key: "HP", value: format!("{}/{}", char_attrs.current_hp, char_attrs.max_hp) },
                Attribute { key: "AC", value: format!("{}", char_attrs.armor_class) },
                Attribute { key: "STR", value: format!("{}", char_attrs.strength) },
                Attribute { key: "DEX", value: format!("{}", char_attrs.dexterity) },
                Attribute { key: "CON", value: format!("{}", char_attrs.constitution) },
                Attribute { key: "INT", value: format!("{}", char_attrs.intelligence) },
                Attribute { key: "WIS", value: format!("{}", char_attrs.wisdom) },
                Attribute { key: "CHA", value: format!("{}", char_attrs.charisma) },
                Attribute { key: "Status", value: if char_attrs.is_dead { "Dead" } else { "Alive" } },
            ];

            let metadata = TokenMetadata {
                token_id,
                name: format!("{} #{}", char_attrs.character_class, token_id.low),
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
