use d20::d20::types::items::ItemType;
use d20::d20::types::spells::SpellId;

// ── Public interface ────────────────────────────────────────────────────────

#[starknet::interface]
pub trait ICombatSystem<TState> {
    /// Attack the monster the character is currently in combat with.
    /// Rolls attack (d20 + STR/DEX mod + proficiency) vs monster AC.
    /// On hit, rolls weapon damage and deducts from MonsterInstance HP.
    /// Monster counter-attacks after the character's action (task 2.5).
    /// Emits CombatResult event.
    fn attack(ref self: TState, character_id: u128);

    /// Wizard: cast a spell (task 2.8).
    /// Handles cantrips (no slot cost) and leveled spells (consume slot).
    /// Monster counter-attacks after the spell unless it is killed.
    fn cast_spell(ref self: TState, character_id: u128, spell_id: SpellId);

    /// Use a consumable item (task 2.8).
    /// HealthPotion: heals 2d4+2 HP.
    fn use_item(ref self: TState, character_id: u128, item_type: ItemType);

    /// Flee from combat (task 2.10 — stub).
    fn flee(ref self: TState, character_id: u128);

    /// Fighter: heal 1d10 + level once per rest (task 2.6).
    fn second_wind(ref self: TState, character_id: u128);

    /// Rogue: disengage from combat without triggering monster counter-attack (task 2.7).
    fn cunning_action(ref self: TState, character_id: u128);
}

// ── Contract ────────────────────────────────────────────────────────────────

#[dojo::contract]
pub mod combat_system {
    use super::ICombatSystem;
    use starknet::get_caller_address;
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use starknet::ContractAddress;

    use d20::d20::types::items::ItemType;
    use d20::d20::types::spells::SpellId;
    use d20::models::config::Config;
    use d20::utils::seeder::SeederTrait;
    use d20::utils::dns::DnsTrait;
    use d20::systems::explorer_token::IExplorerTokenDispatcherTrait;

    use d20::d20::components::combat_component::CombatComponent;
    component!(path: CombatComponent, storage: combat, event: CombatEvent);
    impl CombatInternalImpl = CombatComponent::InternalImpl<ContractState>;

    // ── Storage ──────────────────────────────────────────────────────────────

    #[storage]
    struct Storage {
        #[substorage(v0)]
        combat: CombatComponent::Storage,
    }

    // ── Events ───────────────────────────────────────────────────────────────

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CombatEvent: CombatComponent::Event,
    }

    // ── Initializer ──────────────────────────────────────────────────────────

    fn dojo_init(ref self: ContractState, vrf_address: ContractAddress) {
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
    impl CombatSystemImpl of ICombatSystem<ContractState> {
        fn attack(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.combat.attack(ref world, character_id, ref seeder);
        }

        fn cast_spell(ref self: ContractState, character_id: u128, spell_id: SpellId) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.combat.cast_spell(ref world, character_id, spell_id, ref seeder);
        }

        fn use_item(ref self: ContractState, character_id: u128, item_type: ItemType) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.combat.use_item(ref world, character_id, item_type, ref seeder);
        }

        fn flee(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.combat.flee(ref world, character_id, ref seeder);
        }

        fn second_wind(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut seeder = SeederTrait::from_consume_vrf(world, caller);
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == caller, 'not owner');
            // Execute action
            self.combat.second_wind(ref world, character_id, ref seeder);
        }

        fn cunning_action(ref self: ContractState, character_id: u128) {
            let mut world = self.world_default();
            // Verify ownership
            let explorer_token = world.explorer_token_dispatcher();
            assert(explorer_token.owner_of(character_id.into()) == get_caller_address(), 'not owner');
            // Execute action
            self.combat.cunning_action(ref world, character_id);
        }
    }
}
