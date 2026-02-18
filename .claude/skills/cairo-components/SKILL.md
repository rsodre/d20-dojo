---
name: cairo-components
description: Use when working with Cairo components on Starknet.
license: Apache-2.0
metadata: {"author":"starknet-agentic","version":"1.0.0","org":"keep-starknet-strange"}
keywords: [cairo, contracts, starknet, openzeppelin, components, storage, events, interfaces, erc20, erc721]
allowed-tools: [Bash, Read, Write, Glob, Grep, Task]
user-invocable: true
---

## Components (OpenZeppelin v3 Pattern)

Components are reusable contract modules. This is the standard pattern in Cairo / OZ v3:

### Using a Component

The **Mixin pattern** is the most common approach in OZ v3 — it exposes all standard interface methods (e.g., `balance_of`, `transfer`, `approve`) in a single `impl` block:

```cairo
#[starknet::contract]
mod MyToken {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // Embed external implementations (makes functions callable from outside)
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Internal implementations (for use inside the contract)
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.erc20.initializer("MyToken", "MTK");
    }
}
```

### Writing a Component

```cairo
#[starknet::component]
mod MyComponent {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        value: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ValueChanged: ValueChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct ValueChanged {
        new_value: u256,
    }

    #[embeddable_as(MyComponentImpl)]
    impl MyComponent<
        TContractState, +HasComponent<TContractState>
    > of super::IMyComponent<ComponentState<TContractState>> {
        fn get_value(self: @ComponentState<TContractState>) -> u256 {
            self.value.read()
        }

        fn set_value(ref self: ComponentState<TContractState>, new_value: u256) {
            self.value.write(new_value);
            self.emit(ValueChanged { new_value });
        }
    }
}
```

## Common OpenZeppelin Components

### Scarb.toml Dependencies

```toml
[dependencies]
starknet = ">=2.12.0"
openzeppelin_access = "3.0.0"
openzeppelin_token = "3.0.0"
openzeppelin_upgrades = "3.0.0"
openzeppelin_introspection = "3.0.0"
openzeppelin_security = "3.0.0"
```

> **Note:** OZ packages are on the [Scarb registry](https://scarbs.dev). No git tags needed. Check `scarbs.dev` for the latest version.

### Ownable

```cairo
use openzeppelin_access::ownable::OwnableComponent;

component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

#[abi(embed_v0)]
impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

// In constructor:
self.ownable.initializer(owner);

// In functions:
self.ownable.assert_only_owner();
```

### Upgradeable

```cairo
use openzeppelin_upgrades::UpgradeableComponent;
use openzeppelin_upgrades::interface::IUpgradeable;

component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

#[abi(embed_v0)]
impl UpgradeableImpl of IUpgradeable<ContractState> {
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        self.ownable.assert_only_owner();
        self.upgradeable.upgrade(new_class_hash);
    }
}
```

### ERC20

```cairo
use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};

component!(path: ERC20Component, storage: erc20, event: ERC20Event);

#[abi(embed_v0)]
impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

// In constructor:
self.erc20.initializer("TokenName", "TKN");
self.erc20.mint(recipient, initial_supply);
```

### AccessControl

```cairo
use openzeppelin_access::accesscontrol::AccessControlComponent;
use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;

component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);

#[abi(embed_v0)]
impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;
impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");

// In constructor:
self.access_control.initializer();
self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
self.access_control._grant_role(MINTER_ROLE, minter);

// In functions:
self.access_control.assert_only_role(MINTER_ROLE);
```

## Project Structure

```
my-project/
  Scarb.toml
  src/
    components/
      mod.cairo
      my_component.cairo
```

### lib.cairo

```cairo
mod components {
    my_component;
};
```
