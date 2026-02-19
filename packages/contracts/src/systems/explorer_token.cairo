
// ── Public interface ────────────────────────────────────────────────────────

use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use crate::types::explorer::ExplorerClass;

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
    fn mint_explorer(ref self: TState, class: ExplorerClass) -> u128;
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
    fn mint_explorer(ref self: TState, class: ExplorerClass) -> u128;

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

    // Game types and models
    use d20::types::index::Skill;
    use d20::types::explorer::{ExplorerClass, ExplorerClassTrait};
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

    // ── Standard array (sorted descending) ──────────────────────────────────

    // The standard array values in descending order: [15, 14, 13, 12, 10, 8]
    fn standard_array() -> Span<u8> {
        array![15_u8, 14_u8, 13_u8, 12_u8, 10_u8, 8_u8].span()
    }

    /// Assign stats randomly using VRF with a class-biased shuffle.
    ///
    /// Strategy: use the class's `preferred_stat_order` as a base assignment,
    /// then perform a Fisher-Yates shuffle of the 6 slots using VRF bytes.
    /// This keeps high stats near preferred abilities while introducing variety.
    ///
    /// Returns [STR, DEX, CON, INT, WIS, CHA].
    fn random_stat_assignment(ref seeder: d20::utils::seeder::Seeder, class: ExplorerClass) -> (u8, u8, u8, u8, u8, u8) {
        // Start with the class-preferred order: indices into standard_array()
        // preferred_stat_order returns [STR_idx, DEX_idx, CON_idx, INT_idx, WIS_idx, CHA_idx]
        // Each value is which position in the sorted array (0=15, 1=14, ..., 5=8) to assign.
        let order = class.preferred_stat_order();
        let sa = standard_array();

        // Build a mutable assignment array: assign[ability] = stat_value
        // order[0] = which slot in sa goes to STR, order[1] = which slot goes to DEX, etc.
        let mut assign: Array<u8> = array![
            *sa.at((*order.at(0)).into()),
            *sa.at((*order.at(1)).into()),
            *sa.at((*order.at(2)).into()),
            *sa.at((*order.at(3)).into()),
            *sa.at((*order.at(4)).into()),
            *sa.at((*order.at(5)).into()),
        ];

        // Fisher-Yates shuffle (partial, 3 swaps) adds randomness while preserving
        // rough class bias. Full shuffle would be 5 random swaps.
        // We do 5 swaps for full randomness:
        let r0 = seeder.random_u8();
        let r1 = seeder.random_u8();
        let r2 = seeder.random_u8();
        let r3 = seeder.random_u8();
        let r4 = seeder.random_u8();

        // Swap [5] with [r0 % 6]
        let i0: u32 = (r0 % 6).into();
        let tmp0 = *assign.at(5);
        let v0 = *assign.at(i0);
        let mut assign2: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i0 { assign2.append(tmp0); }
            else if k == 5 { assign2.append(v0); }
            else { assign2.append(*assign.at(k)); }
            k += 1;
        };

        // Swap [4] with [r1 % 5]
        let i1: u32 = (r1 % 5).into();
        let tmp1 = *assign2.at(4);
        let v1 = *assign2.at(i1);
        let mut assign3: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i1 { assign3.append(tmp1); }
            else if k == 4 { assign3.append(v1); }
            else { assign3.append(*assign2.at(k)); }
            k += 1;
        };

        // Swap [3] with [r2 % 4]
        let i2: u32 = (r2 % 4).into();
        let tmp2 = *assign3.at(3);
        let v2 = *assign3.at(i2);
        let mut assign4: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i2 { assign4.append(tmp2); }
            else if k == 3 { assign4.append(v2); }
            else { assign4.append(*assign3.at(k)); }
            k += 1;
        };

        // Swap [2] with [r3 % 3]
        let i3: u32 = (r3 % 3).into();
        let tmp3 = *assign4.at(2);
        let v3 = *assign4.at(i3);
        let mut assign5: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i3 { assign5.append(tmp3); }
            else if k == 2 { assign5.append(v3); }
            else { assign5.append(*assign4.at(k)); }
            k += 1;
        };

        // Swap [1] with [r4 % 2]
        let i4: u32 = (r4 % 2).into();
        let tmp4 = *assign5.at(1);
        let v4 = *assign5.at(i4);
        let mut assign6: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i4 { assign6.append(tmp4); }
            else if k == 1 { assign6.append(v4); }
            else { assign6.append(*assign5.at(k)); }
            k += 1;
        };

        (
            *assign6.at(0), // STR
            *assign6.at(1), // DEX
            *assign6.at(2), // CON
            *assign6.at(3), // INT
            *assign6.at(4), // WIS
            *assign6.at(5), // CHA
        )
    }

    /// Randomly pick skills (and expertise for Rogue) using VRF.
    /// Returns (athletics, stealth, perception, persuasion, arcana, acrobatics, expertise_1, expertise_2).
    fn random_skills(
        ref seeder: d20::utils::seeder::Seeder, class: ExplorerClass
    ) -> (bool, bool, bool, bool, bool, bool, Skill, Skill) {
        match class {
            ExplorerClass::Fighter => {
                let r = seeder.random_u8();
                let chosen = ExplorerClassTrait::random_fighter_skill(r);
                let perception = chosen == Skill::Perception;
                let acrobatics = chosen == Skill::Acrobatics;
                // Fighter always has Athletics; no expertise
                (true, false, perception, false, false, acrobatics, Skill::None, Skill::None)
            },
            ExplorerClass::Rogue => {
                let r0 = seeder.random_u8();
                let r1 = seeder.random_u8();
                let (skill0, skill1) = ExplorerClassTrait::random_rogue_skills(r0, r1);
                let r2 = seeder.random_u8();
                let r3 = seeder.random_u8();
                let (exp0, exp1) = ExplorerClassTrait::random_rogue_expertise(r2, r3, skill0, skill1);
                let athletics = skill0 == Skill::Athletics || skill1 == Skill::Athletics;
                let perception = skill0 == Skill::Perception || skill1 == Skill::Perception;
                let persuasion = skill0 == Skill::Persuasion || skill1 == Skill::Persuasion;
                let arcana = skill0 == Skill::Arcana || skill1 == Skill::Arcana;
                // Rogue always has Stealth and Acrobatics
                (athletics, true, perception, persuasion, arcana, true, exp0, exp1)
            },
            ExplorerClass::Wizard => {
                let r = seeder.random_u8();
                let chosen = ExplorerClassTrait::random_wizard_skill(r);
                let perception = chosen == Skill::Perception;
                let persuasion = chosen == Skill::Persuasion;
                // Wizard always has Arcana; no expertise
                (false, false, perception, persuasion, true, false, Skill::None, Skill::None)
            },
            ExplorerClass::None => {
                (false, false, false, false, false, false, Skill::None, Skill::None)
            },
        }
    }

    // ── Public interface implementation ──────────────────────────────────────

    #[abi(embed_v0)]
    impl ExplorerTokenPublicImpl of super::IExplorerTokenPublic<ContractState> {
        fn mint_explorer(ref self: ContractState, class: ExplorerClass) -> u128 {
            assert(class != ExplorerClass::None, 'must choose a class');

            let mut world = self.world_default();
            let caller = get_caller_address();

            // Consume VRF for all randomization (must be preceded by request_random multicall)
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);

            // Mint the ERC-721 token via cairo-nft-combo sequential minter
            let token_id: u256 = self.erc721_combo._mint_next(caller);

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let explorer_id: u128 = token_id.low;

            // Randomly assign stats from standard array [15,14,13,12,10,8] using VRF
            let (strength, dexterity, constitution, intelligence, wisdom, charisma) =
                random_stat_assignment(ref seeder, class);

            let con_mod: i8 = ability_modifier(constitution);
            let dex_mod: i8 = ability_modifier(dexterity);

            // Starting HP: hit die max + CON modifier (minimum 1)
            let hit_die = class.hit_die_max();
            let raw_hp: i16 = hit_die.into() + con_mod.into();
            let max_hp: u16 = if raw_hp < 1 { 1 } else { raw_hp.try_into().unwrap() };

            // Starting equipment and AC by class
            let (primary_weapon, secondary_weapon, armor, has_shield) = class.starting_equipment();
            let armor_class = calculate_ac(armor, has_shield, dex_mod);

            // Spell slots (level 1)
            let (slots_1, slots_2, slots_3) = class.spell_slots_for(1);

            // Randomly pick skills from VRF
            let (athletics, stealth, perception, persuasion, arcana, acrobatics,
                 expertise_1, expertise_2) = random_skills(ref seeder, class);

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

            explorer_id
        }

        fn rest(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == get_caller_address(), 'not owner');

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
