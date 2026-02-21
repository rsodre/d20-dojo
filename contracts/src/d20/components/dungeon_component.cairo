
#[starknet::interface]
pub trait IDungeon<TState> {
    fn placeholder(ref self: TState);
}

#[starknet::component]
pub mod DungeonComponent {
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(DungeonImpl)]
    impl Dungeon<
        TContractState, +HasComponent<TContractState>
    > of super::IDungeon<ComponentState<TContractState>> {
        fn placeholder(ref self: ComponentState<TContractState>) {}
    }
}
