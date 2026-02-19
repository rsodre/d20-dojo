
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
    fn enter_temple(ref self: TState, explorer_id: u128, temple_id: u128);

    /// Remove an explorer from the temple (set temple_id=0, chamber_id=0).
    fn exit_temple(ref self: TState, explorer_id: u128);

    /// Open an unexplored exit from the explorer's current chamber,
    /// generating the destination chamber if it hasn't been discovered yet.
    fn open_exit(ref self: TState, explorer_id: u128, exit_index: u8);

    /// Move the explorer through a previously discovered exit.
    fn move_to_chamber(ref self: TState, explorer_id: u128, exit_index: u8);

    /// DEX/skill check to disarm a trap in the current chamber.
    fn disarm_trap(ref self: TState, explorer_id: u128);

    /// Loot the current chamber: Perception check (d20 + WIS) in Empty/Treasure chambers,
    /// awards gold and possibly a potion on success. Marks chamber as looted.
    fn loot_treasure(ref self: TState, explorer_id: u128);

    /// Pick up loot from a fallen explorer in the current chamber.
    fn loot_fallen(ref self: TState, explorer_id: u128, fallen_index: u32);
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
    fn enter_temple(ref self: TState, explorer_id: u128, temple_id: u128);

    /// Remove an explorer from the temple (set temple_id=0, chamber_id=0).
    fn exit_temple(ref self: TState, explorer_id: u128);

    /// Open an unexplored exit from the explorer's current chamber,
    /// generating the destination chamber if it hasn't been discovered yet.
    fn open_exit(ref self: TState, explorer_id: u128, exit_index: u8);

    /// Move the explorer through a previously discovered exit.
    fn move_to_chamber(ref self: TState, explorer_id: u128, exit_index: u8);

    /// DEX/skill check to disarm a trap in the current chamber.
    fn disarm_trap(ref self: TState, explorer_id: u128);

    /// Loot the current chamber: Perception check (d20 + WIS) in Empty/Treasure chambers,
    /// awards gold and possibly a potion on success. Marks chamber as looted.
    fn loot_treasure(ref self: TState, explorer_id: u128);

    /// Pick up loot from a fallen explorer in the current chamber.
    fn loot_fallen(ref self: TState, explorer_id: u128, fallen_index: u32);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod temple_token {
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
    use d20::types::index::ChamberType;
    use d20::types::explorer_class::ExplorerClass;
    use d20::types::monster::{MonsterType, MonsterTypeTrait};
    use d20::models::temple::{
        TempleState, Chamber, MonsterInstance, ChamberExit, ExplorerTempleProgress,
        FallenExplorer, ChamberFallenCount,
    };
    use d20::models::explorer::{ExplorerHealth, ExplorerPosition};
    use d20::events::ChamberRevealed;
    use d20::utils::dice::{roll_d20, roll_dice, ability_modifier, proficiency_bonus};
    use d20::utils::seeder::{Seeder, SeederTrait};
    // use d20::utils::monsters::MonsterTypeTrait; // Removed as it is now in types::monster
    use d20::models::explorer::{ExplorerStats, ExplorerInventory, ExplorerSkills};
    use d20::constants::{TEMPLE_TOKEN_DESCRIPTION, TEMPLE_TOKEN_EXTERNAL_LINK};
    use d20::utils::dns::{DnsTrait};
    use d20::systems::explorer_token::{IExplorerTokenDispatcherTrait};

    // Metadata types
    use nft_combo::utils::renderer::{ContractMetadata, TokenMetadata, Attribute};

    // ── Boss probability constants (Yonder Formula) ──────────────────────────
    // See SPEC.md §"Boss Chamber Probability"
    const MIN_YONDER: u8 = 5;
    const YONDER_WEIGHT: u32 = 50;   // bps per effective_yonder²
    const XP_WEIGHT: u32 = 2;        // bps per xp_earned
    const MAX_PROB: u32 = 9500;      // cap at 95%

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

        // ── Boss probability: Yonder Formula (integer-only, bps) ─────────────

        fn calculate_boss_probability(yonder: u8, xp_earned: u32) -> u32 {
            if yonder < MIN_YONDER {
                return 0;
            }
            let effective_yonder: u32 = (yonder - MIN_YONDER).into();
            let yonder_component: u32 = effective_yonder * effective_yonder * YONDER_WEIGHT;
            let xp_component: u32 = xp_earned * XP_WEIGHT;
            let total: u32 = yonder_component + xp_component;
            if total > MAX_PROB { MAX_PROB } else { total }
        }

        // ── Monster type by yonder and difficulty ────────────────────────────
        // Derives from the temple seed + chamber_id hash (pseudo-random, deterministic).
        // Uses a single hash felt to pick both chamber type and monster type.

        fn monster_for_yonder(yonder: u8, difficulty: u8, hash: u256) -> MonsterType {
            // Thematic progression per SPEC:
            //   yonder 0-2:  Snakes, Skeletons
            //   yonder 3-5:  Shadows, Animated Armor
            //   yonder 6-9:  Gargoyles, Mummies
            //   yonder 10+:  Mummies, (Wraith reserved for boss)
            let tier: u8 = if yonder <= 2 { 0 }
                else if yonder <= 5 { 1 }
                else { 2 };

            // difficulty shifts tier up by (difficulty - 1), capped
            let adjusted: u8 = tier + (difficulty - 1);
            let capped: u8 = if adjusted > 2 { 2 } else { adjusted };

            // Pick one of two monsters in tier using hash bit
            let pick: u8 = (hash % 2).try_into().unwrap();
            match capped {
                0 => if pick == 0 { MonsterType::PoisonousSnake } else { MonsterType::Skeleton },
                1 => if pick == 0 { MonsterType::Shadow } else { MonsterType::AnimatedArmor },
                _ => if pick == 0 { MonsterType::Gargoyle } else { MonsterType::Mummy },
            }
        }



        // ── generate_chamber ─────────────────────────────────────────────────
        // Creates a new chamber model derived from the temple seed + parent chamber.
        // Returns the new chamber_id.

        fn generate_chamber(
            ref world: WorldStorage,
            ref seeder: Seeder,
            temple_id: u128,
            parent_chamber_id: u32,
            new_chamber_id: u32,
            yonder: u8,
            explorer_id: u128,
            revealed_by: u128,
            difficulty: u8,
            xp_earned: u32,
            current_max_yonder: u8,
        ) {

            // ── Is this a boss chamber? ──────────────────────────────────────
            let boss_prob: u32 = Self::calculate_boss_probability(yonder, xp_earned);
            let is_boss: bool = if boss_prob > 0 {
                let roll: u32 = roll_d20(ref seeder).into() * 500_u32; // scale 1-20 → 500-10000 bps
                roll <= boss_prob
            } else {
                false
            };

            // ── Generate chamber properties from seeder ──────────────────────
            // We use the seeder (seeded with VRF) for all random decisions.
            // No longer using deterministic hash from temple seed.
            
            let (chamber_type, monster_type) = if is_boss {
                (ChamberType::Boss, MonsterType::Wraith)
            } else {
                // Pick chamber type using VRF
                // 0-2 → Monster (50%), 3 → Treasure (16%), 4 → Trap (16%), 5 → Empty (16%)
                let type_roll: u8 = seeder.random_u8() % 6;
                
                let ct: ChamberType =
                    if type_roll <= 2 { ChamberType::Monster }
                    else if type_roll == 3 { ChamberType::Treasure }
                    else if type_roll == 4 { ChamberType::Trap }
                    else { ChamberType::Empty };
                
                let mt: MonsterType = if ct == ChamberType::Monster {
                    // Pass a random value for the "hash" argument if still needed by helper, 
                    // or better yet, refactor helper.
                    // Checking monster_for_yonder signature: fn monster_for_yonder(yonder: u8, difficulty: u8, hash: u256)
                    // We can just pass a random u256 from seeder.
                    let random_val = seeder.random_u256();
                    Self::monster_for_yonder(yonder, difficulty, random_val)
                } else {
                    MonsterType::None
                };
                (ct, mt)
            };

            // ── Exit count: 0-3 new exits (dead end = 0) ────────────────────
            // At the frontier (yonder >= current max), enforce at least 1 exit
            // so the dungeon always has a path forward.
            let raw_exit_count: u8 = seeder.random_u8() % 4;
            let exit_count: u8 = if raw_exit_count == 0 && yonder >= current_max_yonder {
                1
            } else {
                raw_exit_count
            };

            // ── Trap DC: 10 + yonder/2 + (difficulty - 1)*2 ─────────────────
            let trap_dc: u8 = if chamber_type == ChamberType::Trap {
                10_u8 + yonder / 2 + (difficulty - 1) * 2
            } else {
                0
            };

            // ── Write Chamber model ──────────────────────────────────────────
            world.write_model(@Chamber {
                temple_id,
                chamber_id: new_chamber_id,
                chamber_type,
                yonder,
                exit_count,
                is_revealed: true,
                treasure_looted: false,
                trap_disarmed: false,
                trap_dc,
            });

            // ── Write MonsterInstance if needed ──────────────────────────────
            if monster_type != MonsterType::None {
                let stats = monster_type.get_stats();
                world.write_model(@MonsterInstance {
                    temple_id,
                    chamber_id: new_chamber_id,
                    monster_id: 1,
                    monster_type,
                    current_hp: stats.hp.try_into().unwrap(),
                    max_hp: stats.hp,
                    is_alive: true,
                });
            }

            // ── Initialize exit stubs (undiscovered) ─────────────────────────
            // These placeholders exist so open_exit can validate exit_index bounds.
            let mut i: u8 = 0;
            while i < exit_count {
                world.write_model(@ChamberExit {
                    temple_id,
                    from_chamber_id: new_chamber_id,
                    exit_index: i,
                    to_chamber_id: 0, // unknown until explorer opens it
                    is_discovered: false,
                });
                i += 1;
            };

            // ── Update TempleState: record boss chamber and max_yonder ───────
            // (next_chamber_id already incremented by caller before this call)
            if is_boss || yonder > current_max_yonder {
                let mut temple: TempleState = world.read_model(temple_id);
                if is_boss {
                    temple.boss_chamber_id = new_chamber_id;
                }
                if yonder > current_max_yonder {
                    temple.max_yonder = yonder;
                }
                world.write_model(@temple);
            }

            // ── Emit ChamberRevealed event ───────────────────────────────────
            world.emit_event(@ChamberRevealed {
                temple_id,
                chamber_id: new_chamber_id,
                chamber_type,
                yonder,
                revealed_by,
            });
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

            // Dojo models use u128 keys — high part is always 0 for counter-minted IDs
            let temple_id: u128 = token_id.low;

            // Initialize TempleState
            world.write_model(@TempleState {
                temple_id,
                difficulty_tier: difficulty,
                next_chamber_id: 2, // chamber 1 is the entrance; next new chamber gets id 2
                boss_chamber_id: 0,
                boss_alive: true,
                max_yonder: 0,
            });

            temple_id
        }

        fn enter_temple(ref self: ContractState, explorer_id: u128, temple_id: u128) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == get_caller_address(), 'not owner');

            // Validate temple exists
            let temple: TempleState = world.read_model(temple_id);
            assert(temple.difficulty_tier >= 1, 'temple does not exist');

            // Validate explorer is alive
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot enter');

            // Validate explorer is not in combat; auto-exit current temple if in one
            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(!position.in_combat, 'explorer is in combat');

            // Place explorer at entrance chamber (overwrites any previous temple position)
            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id,
                chamber_id: 1, // entrance chamber is always id 1
                in_combat: false,
                combat_monster_id: 0,
            });

            // Initialize ExplorerTempleProgress for this temple visit
            // (only write if not previously set — existing chambers_explored/xp_earned carry over
            //  from prior visits, so we only initialize on a fresh record)
            let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));
            if progress.chambers_explored == 0 && progress.xp_earned == 0 {
                world.write_model(@ExplorerTempleProgress {
                    explorer_id,
                    temple_id,
                    chambers_explored: 0,
                    xp_earned: 0,
                });
            }
        }

        fn exit_temple(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == get_caller_address(), 'not owner');

            // Validate explorer is in a temple
            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot exit during combat');

            // Clear temple/chamber position — stats, inventory, XP, and
            // ExplorerTempleProgress are all untouched (persisted on-chain).
            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });
        }

        fn open_exit(ref self: ContractState, explorer_id: u128, exit_index: u8) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == caller, 'not owner');

            // ── Validate explorer state ──────────────────────────────────────
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot explore');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot open exit in combat');

            let temple_id = position.temple_id;
            let current_chamber_id = position.chamber_id;

            // ── Validate the exit exists on the current chamber ──────────────
            let current_chamber: Chamber = world.read_model((temple_id, current_chamber_id));
            assert(exit_index < current_chamber.exit_count, 'invalid exit index');

            // ── Check if exit is already discovered ──────────────────────────
            let exit: ChamberExit = world.read_model((temple_id, current_chamber_id, exit_index));
            assert(!exit.is_discovered, 'exit already discovered');

            // ── Allocate new chamber ID ──────────────────────────────────────
            let mut temple: TempleState = world.read_model(temple_id);
            let new_chamber_id: u32 = temple.next_chamber_id;
            temple.next_chamber_id = new_chamber_id + 1;
            world.write_model(@temple);

            // ── Read progress for boss probability ───────────────────────────
            let progress: ExplorerTempleProgress = world.read_model((explorer_id, temple_id));

            // ── Generate the new chamber ─────────────────────────────────────
            let new_yonder: u8 = current_chamber.yonder + 1;
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            InternalTrait::generate_chamber(
                ref world,
                ref seeder,
                temple_id,
                current_chamber_id,
                new_chamber_id,
                new_yonder,
                explorer_id,
                explorer_id, // revealed_by
                temple.difficulty_tier,
                progress.xp_earned,
                temple.max_yonder,
            );

            // ── Create bidirectional ChamberExit links ───────────────────────
            // Forward: current → new (mark discovered)
            world.write_model(@ChamberExit {
                temple_id,
                from_chamber_id: current_chamber_id,
                exit_index,
                to_chamber_id: new_chamber_id,
                is_discovered: true,
            });

            // Back: new → current (exit_index = 0 reserved for return path)
            world.write_model(@ChamberExit {
                temple_id,
                from_chamber_id: new_chamber_id,
                exit_index: 0,
                to_chamber_id: current_chamber_id,
                is_discovered: true,
            });

            // ── Increment chambers_explored on ExplorerTempleProgress ────────
            world.write_model(@ExplorerTempleProgress {
                explorer_id,
                temple_id,
                chambers_explored: progress.chambers_explored + 1,
                xp_earned: progress.xp_earned,
            });
        }

        fn move_to_chamber(ref self: ContractState, explorer_id: u128, exit_index: u8) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == caller, 'not owner');

            // ── Validate explorer state ──────────────────────────────────────
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot move');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot move during combat');

            let temple_id = position.temple_id;
            let current_chamber_id = position.chamber_id;

            // ── Validate exit is discovered ──────────────────────────────────
            let current_chamber: Chamber = world.read_model((temple_id, current_chamber_id));
            assert(exit_index < current_chamber.exit_count, 'invalid exit index');

            let exit: ChamberExit = world.read_model((temple_id, current_chamber_id, exit_index));
            assert(exit.is_discovered, 'exit not yet discovered');

            let dest_chamber_id = exit.to_chamber_id;

            // ── Move explorer to destination chamber ─────────────────────────
            let dest_chamber: Chamber = world.read_model((temple_id, dest_chamber_id));

            // Check for live monster in destination chamber
            let monster: MonsterInstance = world.read_model((temple_id, dest_chamber_id, 1_u32));
            let enters_combat: bool = monster.is_alive && dest_chamber.chamber_type == ChamberType::Monster
                || (monster.is_alive && dest_chamber.chamber_type == ChamberType::Boss);

            world.write_model(@ExplorerPosition {
                explorer_id,
                temple_id,
                chamber_id: dest_chamber_id,
                in_combat: enters_combat,
                combat_monster_id: if enters_combat { 1 } else { 0 },
            });

            // ── Trigger trap on entry if not disarmed ───────────────────────
            // Trap damage dealt on entry: DEX save vs trap_dc.
            // On failed save, explorer takes 1d6 + yonder/2 damage.
            // (Full save resolution reuses VRF; simplified to automatic partial damage here
            //  until task 3.9 disarm_trap is implemented)
            if dest_chamber.chamber_type == ChamberType::Trap && !dest_chamber.trap_disarmed
                && dest_chamber.trap_dc > 0 {
                let mut seeder = SeederTrait::from_consume_vrf(world, caller);
                let stats: ExplorerStats = world.read_model(explorer_id);
                let dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
                // DEX saving throw
                let save_roll: i16 = roll_d20(ref seeder).into() + dex_mod.into();
                let dc_i16: i16 = dest_chamber.trap_dc.into();
                if save_roll < dc_i16 {
                    // Failed save: take 1d6 + yonder/2 piercing damage
                    let base_dmg: u16 = roll_dice(ref seeder, 6, 1);
                    let bonus: u16 = (dest_chamber.yonder / 2).into();
                    let damage: u16 = base_dmg + bonus;
                    let new_hp: i16 = health.current_hp - damage.try_into().unwrap();
                    if new_hp <= 0 {
                        world.write_model(@ExplorerHealth {
                            explorer_id,
                            current_hp: 0,
                            max_hp: health.max_hp,
                            is_dead: true,
                        });
                    } else {
                        world.write_model(@ExplorerHealth {
                            explorer_id,
                            current_hp: new_hp,
                            max_hp: health.max_hp,
                            is_dead: false,
                        });
                    }
                }
            }
        }

        fn disarm_trap(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == caller, 'not owner');

            // ── Validate explorer state ──────────────────────────────────────
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot disarm');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot disarm during combat');

            let temple_id = position.temple_id;
            let chamber_id = position.chamber_id;

            // ── Must be a Trap chamber with an active trap ───────────────────
            let chamber: Chamber = world.read_model((temple_id, chamber_id));
            assert(chamber.chamber_type == ChamberType::Trap, 'no trap in this chamber');
            assert(!chamber.trap_disarmed, 'trap already disarmed');
            assert(chamber.trap_dc > 0, 'no trap in this chamber');

            // ── Disarm check: DEX (Rogue) or INT (others) + proficiency ──────
            // Rogues use DEX + proficiency (with expertise on Stealth/Acrobatics if selected).
            // All other classes use INT + proficiency only if proficient in Arcana.
            // Expertise on the relevant skill doubles the proficiency bonus.
            // Others: INT-based, proficient only if Arcana trained.
            // Expertise on the relevant skill doubles the proficiency bonus.
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            let stats: ExplorerStats = world.read_model(explorer_id);
            let skills: ExplorerSkills = world.read_model(explorer_id);
            let prof: u8 = proficiency_bonus(stats.level);

            // Determine ability score and proficiency multiplier by class
            // Rogue: DEX-based, always proficient (Thieves' Tools), expertise doubles if
            //        acrobatics expertise chosen (acrobatics is a dex skill, close enough).
            // Others: INT-based, proficient only if Arcana trained.
            use d20::types::index::Skill;
            let (ability_score, prof_mult): (u8, u8) = match stats.class {
                ExplorerClass::Rogue => {
                    // Check for expertise on Acrobatics (DEX skill → applies to fine motor work)
                    let expertise_mult: u8 = if skills.expertise_1 == Skill::Acrobatics
                        || skills.expertise_2 == Skill::Acrobatics { 2 } else { 1 };
                    (stats.abilities.dexterity, expertise_mult)
                },
                _ => {
                    // INT check; proficient only if Arcana trained
                    let arcana_mult: u8 = if skills.skills.arcana { 1 } else { 0 };
                    (stats.abilities.intelligence, arcana_mult)
                },
            };

            let ability_mod: i8 = ability_modifier(ability_score);
            let prof_bonus: i8 = (prof * prof_mult).try_into().unwrap();
            let roll: u8 = roll_d20(ref seeder);
            let total: i16 = roll.into() + ability_mod.into() + prof_bonus.into();
            let dc: i16 = chamber.trap_dc.into();

            if total >= dc {
                // ── Success: mark trap disarmed ──────────────────────────────
                world.write_model(@Chamber {
                    temple_id,
                    chamber_id,
                    chamber_type: chamber.chamber_type,
                    yonder: chamber.yonder,
                    exit_count: chamber.exit_count,
                    is_revealed: chamber.is_revealed,
                    treasure_looted: chamber.treasure_looted,
                    trap_disarmed: true,
                    trap_dc: chamber.trap_dc,
                });
            } else {
                // ── Failure: trap fires — DEX save or take damage ────────────
                // Failed disarm attempt triggers the trap:
                // DEX saving throw vs trap_dc; fail → 1d6 + yonder/2 damage.
                let dex_mod: i8 = ability_modifier(stats.abilities.dexterity);
                let save_roll: i16 = roll_d20(ref seeder).into() + dex_mod.into();
                if save_roll < dc {
                    let base_dmg: u16 = roll_dice(ref seeder, 6, 1);
                    let bonus: u16 = (chamber.yonder / 2).into();
                    let damage: u16 = base_dmg + bonus;
                    let new_hp: i16 = health.current_hp - damage.try_into().unwrap();
                    if new_hp <= 0 {
                        world.write_model(@ExplorerHealth {
                            explorer_id,
                            current_hp: 0,
                            max_hp: health.max_hp,
                            is_dead: true,
                        });
                    } else {
                        world.write_model(@ExplorerHealth {
                            explorer_id,
                            current_hp: new_hp,
                            max_hp: health.max_hp,
                            is_dead: false,
                        });
                    }
                }
                // On success of the DEX save: no damage, but trap still armed (can retry)
            }
        }

        fn loot_treasure(ref self: ContractState, explorer_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == caller, 'not owner');

            // ── Validate explorer state ──────────────────────────────────────
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot loot');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot loot during combat');

            let temple_id = position.temple_id;
            let chamber_id = position.chamber_id;

            // ── Only lootable in Empty or Treasure chambers ──────────────────
            let chamber: Chamber = world.read_model((temple_id, chamber_id));
            assert(
                chamber.chamber_type == ChamberType::Empty
                    || chamber.chamber_type == ChamberType::Treasure,
                'nothing to loot here'
            );
            assert(!chamber.treasure_looted, 'already looted');

            // ── Perception check: d20 + WIS mod [+ proficiency if trained] ───
            // DC 12 for Empty chambers, DC 10 for Treasure chambers
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            let stats: ExplorerStats = world.read_model(explorer_id);
            let skills: ExplorerSkills = world.read_model(explorer_id);

            let wis_mod: i8 = ability_modifier(stats.abilities.wisdom);
            let prof: u8 = proficiency_bonus(stats.level);
            let prof_bonus: i8 = if skills.skills.perception { prof.try_into().unwrap() } else { 0 };

            let roll: i16 = roll_d20(ref seeder).into()
                + wis_mod.into()
                + prof_bonus.into();

            let dc: i16 = if chamber.chamber_type == ChamberType::Empty { 12 } else { 10 };

            if roll >= dc {
                // ── Success: award gold and possibly a potion ─────────────────
                // Gold: 1d6 × (yonder + 1) × difficulty
                let gold_roll: u32 = roll_dice(ref seeder, 6, 1).into();
                let temple: TempleState = world.read_model(temple_id);
                let gold_found: u32 = gold_roll
                    * (chamber.yonder.into() + 1)
                    * temple.difficulty_tier.into();

                // Potion found on total roll >= 15
                let potion_found: u8 = if roll >= 15 { 1 } else { 0 };

                let inventory: ExplorerInventory = world.read_model(explorer_id);
                world.write_model(@ExplorerInventory {
                    explorer_id,
                    primary_weapon: inventory.primary_weapon,
                    secondary_weapon: inventory.secondary_weapon,
                    armor: inventory.armor,
                    has_shield: inventory.has_shield,
                    gold: inventory.gold + gold_found,
                    potions: inventory.potions + potion_found,
                });

                // Mark as looted — cannot loot again
                world.write_model(@Chamber {
                    temple_id,
                    chamber_id,
                    chamber_type: chamber.chamber_type,
                    yonder: chamber.yonder,
                    exit_count: chamber.exit_count,
                    is_revealed: chamber.is_revealed,
                    treasure_looted: true,
                    trap_disarmed: chamber.trap_disarmed,
                    trap_dc: chamber.trap_dc,
                });
            }
            // On failed check: nothing found, can retry next turn
        }

        fn loot_fallen(ref self: ContractState, explorer_id: u128, fallen_index: u32) {
            let mut world = self.world_default();

            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(explorer_id.into()) == get_caller_address(), 'not owner');

            // ── Validate explorer state ──────────────────────────────────────
            let health: ExplorerHealth = world.read_model(explorer_id);
            assert(!health.is_dead, 'dead explorers cannot loot');

            let position: ExplorerPosition = world.read_model(explorer_id);
            assert(position.temple_id != 0, 'not inside any temple');
            assert(!position.in_combat, 'cannot loot during combat');

            let temple_id = position.temple_id;
            let chamber_id = position.chamber_id;

            // ── Validate fallen_index is in range ────────────────────────────
            let fallen_count: ChamberFallenCount = world.read_model((temple_id, chamber_id));
            assert(fallen_index < fallen_count.count, 'no body at that index');

            // ── Read the FallenExplorer record ───────────────────────────────
            let fallen: FallenExplorer = world.read_model((temple_id, chamber_id, fallen_index));
            assert(!fallen.is_looted, 'already looted');

            // ── Cannot loot yourself (edge case: somehow same explorer_id) ───
            assert(fallen.explorer_id != explorer_id, 'cannot loot yourself');

            // ── Merge dropped loot into explorer's inventory ─────────────────
            // Weapons: only take if explorer has None in that slot
            // Armor:   only upgrade if dropped armor > current (or current is None)
            // Gold + potions: always add
            let inventory: ExplorerInventory = world.read_model(explorer_id);

            use d20::types::items::{WeaponType, ArmorType};

            let new_primary: WeaponType = if inventory.primary_weapon == WeaponType::None {
                fallen.dropped_weapon
            } else {
                inventory.primary_weapon
            };

            // Secondary slot: take dropped weapon if secondary is empty and primary already used it
            let new_secondary: WeaponType = if inventory.secondary_weapon == WeaponType::None
                && new_primary != fallen.dropped_weapon {
                fallen.dropped_weapon
            } else {
                inventory.secondary_weapon
            };

            // Armor: upgrade if currently wearing nothing and fallen had armor
            let new_armor: ArmorType = if inventory.armor == ArmorType::None {
                fallen.dropped_armor
            } else {
                inventory.armor
            };

            world.write_model(@ExplorerInventory {
                explorer_id,
                primary_weapon: new_primary,
                secondary_weapon: new_secondary,
                armor: new_armor,
                has_shield: inventory.has_shield,
                gold: inventory.gold + fallen.dropped_gold,
                potions: inventory.potions + fallen.dropped_potions,
            });

            // ── Mark fallen explorer as looted ───────────────────────────────
            world.write_model(@FallenExplorer {
                temple_id,
                chamber_id,
                fallen_index,
                explorer_id: fallen.explorer_id,
                dropped_weapon: fallen.dropped_weapon,
                dropped_armor: fallen.dropped_armor,
                dropped_gold: fallen.dropped_gold,
                dropped_potions: fallen.dropped_potions,
                is_looted: true,
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
