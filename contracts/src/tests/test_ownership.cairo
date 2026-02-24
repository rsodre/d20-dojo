#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::syscalls::deploy_syscall;
    use dojo::world::{WorldStorage, WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait
    };

    use d20::systems::explorer_token::{IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait};
    use d20::systems::temple_token::{ITempleTokenDispatcher, ITempleTokenDispatcherTrait};
    use d20::d20::types::character_class::CharacterClass;
    use d20::tests::mock_vrf::MockVrf;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_2",
            resources: array![
                TestResource::Model(d20::models::config::m_Config::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterStats::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterCombat::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterInventory::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterPosition::TEST_CLASS_HASH),
                TestResource::Model(d20::d20::models::character::m_CharacterSkills::TEST_CLASS_HASH),
                TestResource::Event(d20::d20::models::events::e_CharacterMinted::TEST_CLASS_HASH),
                TestResource::Contract(d20::systems::explorer_token::explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(d20::systems::temple_token::temple_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    fn setup_world() -> WorldStorage {
        let (mock_vrf_address, _) = deploy_syscall(
            MockVrf::TEST_CLASS_HASH, 0, [].span(), false,
        ).unwrap_syscall();

        let contract_defs: Span<ContractDef> = array![
            ContractDefTrait::new(@"d20_0_2", @"explorer_token")
                .with_writer_of(array![dojo::utils::bytearray_hash(@"d20_0_2")].span())
                .with_init_calldata(array![mock_vrf_address.into()].span()),
            ContractDefTrait::new(@"d20_0_2", @"temple_token")
                .with_writer_of(array![dojo::utils::bytearray_hash(@"d20_0_2")].span()),
        ].span();

        let mut world = spawn_test_world(world::TEST_CLASS_HASH, array![namespace_def()].span());
        world.sync_perms_and_inits(contract_defs);
        world
    }

    #[test]
    #[should_panic(expected: ('not owner', 'ENTRYPOINT_FAILED'))]
    fn test_rest_rejects_non_owner() {
        let mut world = setup_world();
        let (explorer_token_addr, _) = world.dns(@"explorer_token").unwrap();
        let explorer_token = IExplorerTokenDispatcher {
            contract_address: explorer_token_addr
        };

        let owner: ContractAddress = 0x123.try_into().unwrap();
        let non_owner: ContractAddress = 0x456.try_into().unwrap();

        // Mint explorer as owner
        starknet::testing::set_contract_address(owner);
        let character_id = explorer_token.mint_explorer(CharacterClass::Fighter);

        // Try to rest as non-owner
        starknet::testing::set_contract_address(non_owner);
        explorer_token.rest(character_id);
    }

    #[test]
    #[should_panic(expected: ('not owner', 'ENTRYPOINT_FAILED'))]
    fn test_enter_temple_rejects_non_owner() {
        let mut world = setup_world();
        let (explorer_token_addr, _) = world.dns(@"explorer_token").unwrap();
        let (temple_token_addr, _) = world.dns(@"temple_token").unwrap();

        let explorer_token = IExplorerTokenDispatcher {
            contract_address: explorer_token_addr
        };
        let temple_token = ITempleTokenDispatcher {
            contract_address: temple_token_addr
        };

        let owner: ContractAddress = 0x123.try_into().unwrap();
        let non_owner: ContractAddress = 0x456.try_into().unwrap();

        // Mint explorer as owner
        starknet::testing::set_contract_address(owner);
        let character_id = explorer_token.mint_explorer(CharacterClass::Fighter);

        // Try to enter temple as non-owner
        starknet::testing::set_contract_address(non_owner);
        temple_token.enter_temple(character_id, 1);
    }
}
