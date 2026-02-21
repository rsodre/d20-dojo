
#[starknet::interface]
pub trait ICombat<TState> {
    fn placeholder(ref self: TState);
}

#[starknet::component]
pub mod CombatComponent {
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(CombatImpl)]
    impl Combat<
        TContractState, +HasComponent<TContractState>
    > of super::ICombat<ComponentState<TContractState>> {
        fn placeholder(ref self: ComponentState<TContractState>) {}
    }
}
