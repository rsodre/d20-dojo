
#[starknet::interface]
pub trait ICharacter<TState> {
    fn generate_character(ref self: TState);
}

#[starknet::component]
pub mod CharacterComponent {
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(CharacterImpl)]
    impl Character<
        TContractState, +HasComponent<TContractState>
    > of super::ICharacter<ComponentState<TContractState>> {
        fn generate_character(ref self: ComponentState<TContractState>) {}
    }
}
