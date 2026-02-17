// ── Public interface ────────────────────────────────────────────────────────

#[starknet::interface]
pub trait ITempleToken<TState> {
    /// Mint a new Temple NFT.
    ///
    /// Parameters:
    /// - `seed`: felt252 seed that drives all procedural generation for this temple
    /// - `difficulty`: difficulty tier (1 = easy, higher = harder)
    ///
    /// Returns the new temple's token ID (u256, ERC-721 standard).
    fn mint_temple(ref self: TState, seed: felt252, difficulty: u8) -> u256;

    /// Place an explorer at the temple's entrance chamber.
    fn enter_temple(ref self: TState, explorer_id: u128, temple_id: u128);

    /// Remove an explorer from the temple (set temple_id=0, chamber_id=0).
    fn exit_temple(ref self: TState, explorer_id: u128);

    /// Open an unexplored exit from the explorer's current chamber,
    /// generating the destination chamber if it hasn't been discovered yet.
    fn open_exit(ref self: TState, explorer_id: u128, exit_index: u8);

    /// Move the explorer through a previously discovered exit.
    fn move_to_chamber(ref self: TState, explorer_id: u128, exit_index: u8);

    /// Perception check: reveal hidden traps or treasure in the current chamber.
    fn search_chamber(ref self: TState, explorer_id: u128);

    /// DEX/skill check to disarm a trap in the current chamber.
    fn disarm_trap(ref self: TState, explorer_id: u128);

    /// Pick up treasure from the current chamber.
    fn loot_treasure(ref self: TState, explorer_id: u128);

    /// Pick up loot from a fallen explorer in the current chamber.
    fn loot_fallen(ref self: TState, explorer_id: u128, fallen_index: u32);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod temple_token {
    use super::ITempleToken;
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

    // Game types and models
    use d20::models::temple::{TempleState};
    use d20::models::explorer::{ExplorerPosition};
    use d20::constants::{TEMPLE_TOKEN_DESCRIPTION, TEMPLE_TOKEN_EXTERNAL_LINK};

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
            self.world(@"d20_0_1")
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl TempleTokenImpl of ITempleToken<ContractState> {
        fn mint_temple(ref self: ContractState, seed: felt252, difficulty: u8) -> u256 {
            assert(difficulty >= 1, 'difficulty must be at least 1');

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let temple_id: u128 = token_id.low;

            // Initialize TempleState
            world.write_model(@TempleState {
                temple_id,
                seed,
                difficulty_tier: difficulty,
                next_chamber_id: 2, // chamber 1 is the entrance; next new chamber gets id 2
                boss_chamber_id: 0,
                boss_alive: true,
            });

            token_id
        }

        fn enter_temple(ref self: ContractState, explorer_id: u128, temple_id: u128) {
            let mut world = self.world_default();

            let temple: TempleState = world.read_model(temple_id);
            assert(temple.difficulty_tier >= 1, 'temple does not exist');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id == 0, 'already inside a temple');
            assert(!position.in_combat, 'explorer is in combat');

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id,
                chamber_id: 1, // entrance chamber
                in_combat: false,
                combat_monster_id: 0,
            });
        }

        fn exit_temple(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot exit during combat');

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });
        }

        fn open_exit(ref self: ContractState, explorer_id: u128, exit_index: u8) {
            // Full implementation in task 3.6
            assert(false, 'not yet implemented');
        }

        fn move_to_chamber(ref self: ContractState, explorer_id: u128, exit_index: u8) {
            // Full implementation in task 3.7
            assert(false, 'not yet implemented');
        }

        fn search_chamber(ref self: ContractState, explorer_id: u128) {
            // Full implementation in task 3.8
            assert(false, 'not yet implemented');
        }

        fn disarm_trap(ref self: ContractState, explorer_id: u128) {
            // Full implementation in task 3.9
            assert(false, 'not yet implemented');
        }

        fn loot_treasure(ref self: ContractState, explorer_id: u128) {
            // Full implementation in task 3.10
            assert(false, 'not yet implemented');
        }

        fn loot_fallen(ref self: ContractState, explorer_id: u128, fallen_index: u32) {
            // Full implementation in task 3.10
            assert(false, 'not yet implemented');
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
            let temple_id: u128 = token_id.low;

            let temple: TempleState = world.read_model(temple_id);

            let status: ByteArray = if temple.boss_alive { "Active" } else { "Conquered" };

            let attributes: Array<Attribute> = array![
                Attribute { key: "Difficulty", value: format!("{}", temple.difficulty_tier) },
                Attribute { key: "Status", value: status },
                Attribute { key: "Boss Chamber", value: format!("{}", temple.boss_chamber_id) },
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
