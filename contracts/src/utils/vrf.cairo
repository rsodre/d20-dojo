//! Local Cartridge VRF interface.
//!
//! We define the VRF provider interface locally instead of depending on the
//! `cartridge_vrf` crate to avoid transitive OpenZeppelin dependency conflicts.
//! Only the cross-contract interface and the Source enum are needed.

use starknet::ContractAddress;

/// Randomness source type — mirrors `cartridge_vrf::Source`.
#[derive(Drop, Copy, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}

/// Cartridge VRF provider interface (cross-contract call).
/// The full interface is defined in the cartridge-gg/vrf repo; we only
/// declare the subset we need so the compiler can generate the dispatcher.
#[starknet::interface]
pub trait IVrfProvider<TContractState> {
    fn consume_random(ref self: TContractState, source: Source) -> felt252;
}

/// Cartridge VRF provider contract address (same on Mainnet and Sepolia).
pub const VRF_PROVIDER_ADDRESS: felt252 =
    0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f;
