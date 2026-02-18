/// Minimal mock VRF provider for testing.
/// Returns a deterministic but varying felt252 per call using a counter.
/// Deploy at VRF_PROVIDER_ADDRESS (0x051fea...ced8f) so combat system tests work.
#[starknet::interface]
pub trait IMockVrf<TContractState> {
    fn consume_random(ref self: TContractState, source: d20::utils::vrf::Source) -> felt252;
}

#[starknet::contract]
pub mod MockVrf {
    use d20::utils::vrf::Source;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        counter: felt252,
    }

    #[abi(embed_v0)]
    impl MockVrfImpl of super::IMockVrf<ContractState> {
        fn consume_random(ref self: ContractState, source: Source) -> felt252 {
            let current = self.counter.read();
            // Produce a non-zero, varying value each call.
            // Spread values so dice results vary across the range.
            let next = if current == 0 {
                // 7 → d20 rolls to: (7 % 20) + 1 = 8
                7
            } else if current == 7 {
                // 13 → (13 % 20) + 1 = 14
                13
            } else if current == 13 {
                // 3 → (3 % 20) + 1 = 4
                3
            } else {
                current + 3
            };
            self.counter.write(next);
            next
        }
    }
}
