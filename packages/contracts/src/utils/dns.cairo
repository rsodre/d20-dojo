use starknet::{ContractAddress};
use core::num::traits::Zero;
use dojo::world::{WorldStorage, WorldStorageTrait};
use dojo::meta::interface::{
    IDeployedResourceDispatcher, IDeployedResourceDispatcherTrait,
    IDeployedResourceSafeDispatcher, IDeployedResourceSafeDispatcherTrait,
};

// Dispatchers
use crate::systems::explorer_token::{IExplorerTokenDispatcher};
use crate::systems::temple_token::{ITempleTokenDispatcher};
use crate::systems::combat_system::{ICombatSystemDispatcher};

pub mod SELECTORS {
    pub const EXPLORER_TOKEN: felt252 = selector_from_tag!("d20-explorer_token");
    pub const TEMPLE_TOKEN: felt252 = selector_from_tag!("d20-temple_token");
    pub const COMBAT_SYSTEM: felt252 = selector_from_tag!("d20-combat_system");
}

#[generate_trait]
pub impl DnsImpl of DnsTrait {
    #[inline(always)]
    fn find_contract_name(self: @WorldStorage, contract_address: ContractAddress) -> ByteArray {
        (IDeployedResourceDispatcher{contract_address}.dojo_name())
    }
    
    fn find_contract_address(self: @WorldStorage, contract_name: @ByteArray) -> ContractAddress {
        (self.dns_address(contract_name).unwrap_or(Zero::zero()))
    }

    // --------------------------
    // system addresses
    //
    #[inline(always)]
    fn explorer_token_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"explorer_token"))
    }
    
    #[inline(always)]
    fn temple_token_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"temple_token"))
    }
    
    #[inline(always)]
    fn combat_system_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"combat_system"))
    }

    // --------------------------
    // dispatchers
    //
    #[inline(always)]
    fn explorer_token_dispatcher(self: @WorldStorage) -> IExplorerTokenDispatcher {
        (IExplorerTokenDispatcher{ contract_address: self.explorer_token_address() })
    }
    
    #[inline(always)]
    fn temple_token_dispatcher(self: @WorldStorage) -> ITempleTokenDispatcher {
        (ITempleTokenDispatcher{ contract_address: self.temple_token_address() })
    }
    
    #[inline(always)]
    fn combat_system_dispatcher(self: @WorldStorage) -> ICombatSystemDispatcher {
        (ICombatSystemDispatcher{ contract_address: self.combat_system_address() })
    }

    // --------------------------
    // validators
    //
    #[inline(always)]
    fn caller_is_explorer_token(self: @WorldStorage) -> bool {
        (starknet::get_caller_address() == self.explorer_token_address())
    }
    
    #[inline(always)]
    fn caller_is_temple_token(self: @WorldStorage) -> bool {
        (starknet::get_caller_address() == self.temple_token_address())
    }
    
    #[inline(always)]
    fn caller_is_combat_system(self: @WorldStorage) -> bool {
        (starknet::get_caller_address() == self.combat_system_address())
    }

    #[feature("safe_dispatcher")]
    fn is_world_contract(self: @WorldStorage, contract_address: ContractAddress) -> bool {
        let response: Result<ByteArray, Array<felt252>> = IDeployedResourceSafeDispatcher{contract_address}.dojo_name();
        (match response {
            Result::Ok(contract_name) => (
                contract_address.is_non_zero() &&
                contract_address == self.find_contract_address(@contract_name)
            ),
            Result::Err(_) => (false),
        })
    }
}

#[cfg(test)]
mod tests {
    use starknet::{SyscallResultTrait};
    use core::num::traits::Zero;
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait,
    };

    use d20::systems::explorer_token::{explorer_token};
    use d20::systems::combat_system::{combat_system};
    use d20::systems::temple_token::{temple_token};
    use d20::models::config::m_Config;
    use d20::tests::mock_vrf::MockVrf;
    use super::{DnsTrait, DnsImpl};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: [
                TestResource::Model(m_Config::TEST_CLASS_HASH),
                TestResource::Contract(explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(combat_system::TEST_CLASS_HASH),
                TestResource::Contract(temple_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    fn setup_world() -> dojo::world::WorldStorage {
        let mock_vrf_class_hash = MockVrf::TEST_CLASS_HASH;
        let (mock_vrf_address, _) = starknet::syscalls::deploy_syscall(
            mock_vrf_class_hash, 0, array![].span(), false
        ).unwrap_syscall();

        let contract_defs: Span<ContractDef> = array![
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
                .with_writer_of(array![dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata(array![mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_1", @"combat_system")
                .with_writer_of(array![dojo::utils::bytearray_hash(@"d20_0_1")].span())
                .with_init_calldata(array![mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_1", @"temple_token")
                .with_writer_of(array![dojo::utils::bytearray_hash(@"d20_0_1")].span()),
        ].span();

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, array![namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);
        world
    }

    #[test]
    fn test_dns_addresses() {
        let world = setup_world();
        
        // Check if addresses are resolvable
        let explorer_addr = world.explorer_token_address();
        let temple_addr = world.temple_token_address();
        let combat_addr = world.combat_system_address();

        assert(explorer_addr.is_non_zero(), 'explorer address 0');
        assert(temple_addr.is_non_zero(), 'temple address 0');
        assert(combat_addr.is_non_zero(), 'combat address 0');
        
        let (expected_explorer, _) = world.dns(@"explorer_token").unwrap();
        assert(explorer_addr == expected_explorer, 'explorer address mismatch');
    }

    #[test]
    fn test_dns_dispatchers() {
        let world = setup_world();
        
        let explorer_disp = world.explorer_token_dispatcher();
        let temple_disp = world.temple_token_dispatcher();
        let combat_disp = world.combat_system_dispatcher();

        assert(explorer_disp.contract_address.is_non_zero(), 'explorer disp addr 0');
        assert(temple_disp.contract_address.is_non_zero(), 'temple disp addr 0');
        assert(combat_disp.contract_address.is_non_zero(), 'combat disp addr 0');
    }

    #[test]
    fn test_dns_contract_name() {
        let world = setup_world();
        let explorer_addr = world.explorer_token_address();
        
        let name = world.find_contract_name(explorer_addr);
        assert(name == "explorer_token", 'wrong contract name');
    }
}
