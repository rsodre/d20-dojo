
// ── Public interface ────────────────────────────────────────────────────────
use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait ITempleToken<TState> {
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

    /// Mint a new Temple NFT.
    ///
    /// Parameters:
    /// - `difficulty`: difficulty tier (1 = easy, higher = harder)
    ///
    /// Returns the new temple's token ID (u256, ERC-721 standard).
    fn mint_temple(ref self: TState, difficulty: u8) -> u128;

    /// Place an explorer at the temple's entrance chamber.
    fn enter_temple(ref self: TState, character_id: u128, dungeon_id: u128);

    /// Remove an explorer from the temple (set dungeon_id=0, chamber_id=0).
    fn exit_temple(ref self: TState, character_id: u128);

    /// Open an unexplored exit from the character's current chamber,
    /// generating the destination chamber if it hasn't been discovered yet.
    fn open_exit(ref self: TState, character_id: u128, exit_index: u8);

    /// Move the character through a previously discovered exit.
    fn move_to_chamber(ref self: TState, character_id: u128, exit_index: u8);

    /// DEX/skill check to disarm a trap in the current chamber.
    fn disarm_trap(ref self: TState, character_id: u128);

    /// Loot the current chamber: Perception check (d20 + WIS) in Empty/Treasure chambers,
    /// awards gold and possibly a potion on success. Marks chamber as looted.
    fn loot_treasure(ref self: TState, character_id: u128);

    /// Pick up loot from a fallen explorer in the current chamber.
    fn loot_fallen(ref self: TState, character_id: u128, fallen_index: u32);
}

#[starknet::interface]
pub trait ITempleTokenPublic<TState> {
    /// Mint a new Temple NFT.
    ///
    /// Parameters:
    /// - `difficulty`: difficulty tier (1 = easy, higher = harder)
    ///
    /// Returns the new temple's token ID (u256, ERC-721 standard).
    fn mint_temple(ref self: TState, difficulty: u8) -> u128;

    /// Place an explorer at the temple's entrance chamber.
    fn enter_temple(ref self: TState, character_id: u128, dungeon_id: u128);

    /// Remove an explorer from the temple (set dungeon_id=0, chamber_id=0).
    fn exit_temple(ref self: TState, character_id: u128);

    /// Open an unexplored exit from the character's current chamber,
    /// generating the destination chamber if it hasn't been discovered yet.
    fn open_exit(ref self: TState, character_id: u128, exit_index: u8);

    /// Move the character through a previously discovered exit.
    fn move_to_chamber(ref self: TState, character_id: u128, exit_index: u8);

    /// DEX/skill check to disarm a trap in the current chamber.
    fn disarm_trap(ref self: TState, character_id: u128);

    /// Loot the current chamber: Perception check (d20 + WIS) in Empty/Treasure chambers,
    /// awards gold and possibly a potion on success. Marks chamber as looted.
    fn loot_treasure(ref self: TState, character_id: u128);

    /// Pick up loot from a fallen explorer in the current chamber.
    fn loot_fallen(ref self: TState, character_id: u128, fallen_index: u32);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod temple_token {
    use starknet::get_caller_address;
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

    // Dungeon component
    use d20::d20::components::dungeon_component::DungeonComponent;
    component!(path: DungeonComponent, storage: dungeon, event: DungeonEvent);
    impl DungeonInternalImpl = DungeonComponent::InternalImpl<ContractState>;

    // Game types and models
    use d20::d20::models::dungeon::DungeonState;
    use d20::utils::seeder::SeederTrait;
    use d20::utils::dns::DnsTrait;
    use d20::constants::{TEMPLE_TOKEN_DESCRIPTION, TEMPLE_TOKEN_EXTERNAL_LINK};
    use d20::systems::explorer_token::IExplorerTokenDispatcherTrait;

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
        dungeon: DungeonComponent::Storage,
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
        DungeonEvent: DungeonComponent::Event,
    }

    // ── Token defaults ───────────────────────────────────────────────────────

    pub fn TOKEN_NAME() -> ByteArray { "D20 Temple" }
    pub fn TOKEN_SYMBOL() -> ByteArray { "TEMPLE" }

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
            self.world(@"d20_0_2")
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl TempleTokenPublicImpl of super::ITempleTokenPublic<ContractState> {
        fn mint_temple(ref self: ContractState, difficulty: u8) -> u128 {
            assert(difficulty >= 1, 'difficulty must be at least 1');

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);
            let dungeon_id: u128 = token_id.low;

            // Initialize dungeon state for this temple
            self.dungeon.init_dungeon(ref world, dungeon_id, difficulty);

            dungeon_id
        }

        fn enter_temple(ref self: ContractState, character_id: u128, dungeon_id: u128) {
            let mut world = self.world_default();
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == get_caller_address(), 'not owner');
            // Execute action
            self.dungeon.enter_dungeon(ref world, character_id, dungeon_id);
        }

        fn exit_temple(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == get_caller_address(), 'not owner');
            // Execute action
            self.dungeon.exit_dungeon(ref world, character_id);
        }

        fn open_exit(ref self: ContractState, character_id: u128, exit_index: u8) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.dungeon.open_exit(ref world, character_id, exit_index, ref seeder);
        }

        fn move_to_chamber(ref self: ContractState, character_id: u128, exit_index: u8) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.dungeon.move_to_chamber(ref world, character_id, exit_index, ref seeder);
        }

        fn disarm_trap(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.dungeon.disarm_trap(ref world, character_id, ref seeder);
        }

        fn loot_treasure(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.dungeon.loot_treasure(ref world, character_id, ref seeder);
        }

        fn loot_fallen(ref self: ContractState, character_id: u128, fallen_index: u32) {
            let mut world = self.world_default();
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == get_caller_address(), 'not owner');
            // Execute action
            self.dungeon.loot_fallen(ref world, character_id, fallen_index);
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
                description: TEMPLE_TOKEN_DESCRIPTION(),
                image: Option::None,
                banner_image: Option::None,
                featured_image: Option::None,
                external_link: Option::Some(TEMPLE_TOKEN_EXTERNAL_LINK()),
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
            let dungeon_id: u128 = token_id.low;

            let dungeon: DungeonState = world.read_model(dungeon_id);

            let status: ByteArray = if dungeon.boss_alive { "Active" } else { "Conquered" };

            let attributes: Array<Attribute> = array![
                Attribute { key: "Difficulty", value: format!("{}", dungeon.difficulty_tier) },
                Attribute { key: "Status", value: status },
                Attribute { key: "Boss Chamber", value: format!("{}", dungeon.boss_chamber_id) },
            ];

            let metadata = TokenMetadata {
                token_id,
                name: format!("Temple #{}", token_id.low),
                description: TEMPLE_TOKEN_DESCRIPTION(),
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
