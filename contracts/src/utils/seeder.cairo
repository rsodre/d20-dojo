use core::num::traits::Zero;
use starknet::ContractAddress;
use d20::utils::vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use d20::models::config::Config;
use core::poseidon::poseidon_hash_span;

#[derive(Drop, Copy, Serde)]
pub struct Seeder {
    pub seed: felt252,
    pub hash: u256,
    pub nonce: felt252,
}

#[generate_trait]
pub impl SeederImpl of SeederTrait {
    fn from_consume_vrf(world: WorldStorage, caller: ContractAddress) -> Seeder {
        let config: Config = world.read_model(1_u8);
        let vrf_provider = IVrfProviderDispatcher { contract_address: config.vrf_address };
        let random_felt = vrf_provider.consume_random(Source::Nonce(caller));
        Seeder { seed: random_felt, hash: 0, nonce: 0 }
    }

    fn from_seed(seed: felt252) -> Seeder {
        Seeder { seed: seed, hash: 0, nonce: 0 }
    }

    // fn random_felt(ref self: Seeder) -> felt252 {
    //     let mut data = array![self.seed, self.nonce];
    //     let hash = poseidon_hash_span(data.span());
    //     self.nonce += 1;
    //     hash
    // }

    // optimized for u8 outputs
    fn random_u256(ref self: Seeder) -> u256 {
        if self.nonce.is_zero() {
            self.hash = self.seed.into();
        } else {
            self.hash = self.hash / 0x100;
        }
        if self.hash < 0x100 {
            let mut data = array![self.seed, self.nonce];
            self.hash = poseidon_hash_span(data.span()).into();
        }
        self.nonce += 1;
        self.hash
    }

    fn random_u8(ref self: Seeder) -> u8 {
        (self.random_u256().low & 0xff).try_into().unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::{SeederTrait};

    #[test]
    fn test_seeder_deterministic() {
        let seed = 12345;
        let mut seeder1 = SeederTrait::from_seed(seed);
        let mut seeder2 = SeederTrait::from_seed(seed);

        let r1 = seeder1.random_u256();
        let r2 = seeder2.random_u256();

        assert(r1 == r2, 'seeder not deterministic');
    }

    #[test]
    fn test_seeder_changes_nonce() {
        let seed = 12345;
        let mut seeder = SeederTrait::from_seed(seed);

        let r1 = seeder.random_u256();
        let r2 = seeder.random_u256();

        assert(r1 != r2, 'seeder repetition');
        assert(seeder.nonce == 2, 'nonce not incremented');
    }

    #[test]
    fn test_random_u8() {
        let seed = 11111;
        let mut seeder = SeederTrait::from_seed(seed);
        
        let r: u8 = seeder.random_u8();
        // Just check it runs and returns a u8. 
        // 0 is a valid u8, so we don't necessarily assert > 0, 
        // but we can check it doesn't panic.
        assert(r <= 255, 'u8 overflow'); // tautology but good for sanity
    }

    #[test]
    fn test_random_u8_deterministic() {
        let seed = 99999;
        let mut seeder1 = SeederTrait::from_seed(seed);
        let mut seeder2 = SeederTrait::from_seed(seed);

        let r1 = seeder1.random_u8();
        let r2 = seeder2.random_u8();

        assert(r1 == r2, 'random_u8 not deterministic');
    }
}
