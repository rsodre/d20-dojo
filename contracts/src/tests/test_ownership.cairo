#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::syscalls::deploy_syscall;
    use dojo::world::{WorldStorage, WorldStorageTrait, world};
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
        WorldStorageTestTrait
    };

    use d20::systems::explorer_token::{explorer_token, IExplorerTokenDispatcher, IExplorerTokenDispatcherTrait};
    use d20::systems::temple_token::{temple_token, ITempleTokenDispatcher, ITempleTokenDispatcherTrait};
    use d20::models::config::m_Config;
    use d20::d20::models::adventurer::{
        m_ExplorerStats, m_ExplorerHealth, m_ExplorerCombat,
        m_ExplorerInventory, m_ExplorerPosition, m_ExplorerSkills,
    };
    use d20::events::e_ExplorerMinted;
    use d20::d20::types::adventurer_class::AdventurerClass;
    use d20::tests::mock_vrf::MockVrf;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "d20_0_1",
            resources: array![
                TestResource::Model(m_Config::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerStats::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerHealth::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerCombat::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerInventory::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerPosition::TEST_CLASS_HASH),
                TestResource::Model(m_ExplorerSkills::TEST_CLASS_HASH),
                TestResource::Event(e_ExplorerMinted::TEST_CLASS_HASH),
                TestResource::Contract(explorer_token::TEST_CLASS_HASH),
                TestResource::Contract(temple_token::TEST_CLASS_HASH),
            ].span(),
        }
    }

    fn setup_world() -> WorldStorage {
        let (mock_vrf_address, _) = deploy_syscall(
            MockVrf::TEST_CLASS_HASH, 0, [].span(), false,
        ).unwrap_syscall();

        let contract_defs: Span<ContractDef> = array![
            ContractDefTrait::new(@"d20_0_1", @"explorer_token")
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
        let adventurer_id = explorer_token.mint_explorer(AdventurerClass::Fighter);

        // Try to rest as non-owner
        starknet::testing::set_contract_address(non_owner);
        explorer_token.rest(adventurer_id);
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
        let adventurer_id = explorer_token.mint_explorer(AdventurerClass::Fighter);

        // Try to enter temple as non-owner
        starknet::testing::set_contract_address(non_owner);
        temple_token.enter_temple(adventurer_id, 1);
    }
}
