use starknet::ContractAddress;

/// Singleton world configuration.
/// Always read/written with key = 1.
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Config {
    #[key]
    pub key: u8,                      // always 1 — singleton
    pub vrf_address: ContractAddress, // Cartridge VRF provider address
}
