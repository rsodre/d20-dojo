import { DojoProvider, DojoCall } from "@dojoengine/core";
import { Account, AccountInterface, BigNumberish, CairoCustomEnum } from "starknet";
// import * as models from "./models.gen";

export function setupWorld(provider: DojoProvider) {

	const build_combat_system_attack_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "attack",
			calldata: [explorerId],
		};
	};

	const combat_system_attack = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_attack_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_combat_system_castSpell_calldata = (explorerId: BigNumberish, spellId: CairoCustomEnum): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "cast_spell",
			calldata: [explorerId, spellId],
		};
	};

	const combat_system_castSpell = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, spellId: CairoCustomEnum) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_castSpell_calldata(explorerId, spellId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_combat_system_cunningAction_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "cunning_action",
			calldata: [explorerId],
		};
	};

	const combat_system_cunningAction = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_cunningAction_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_combat_system_flee_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "flee",
			calldata: [explorerId],
		};
	};

	const combat_system_flee = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_flee_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_combat_system_secondWind_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "second_wind",
			calldata: [explorerId],
		};
	};

	const combat_system_secondWind = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_secondWind_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_combat_system_useItem_calldata = (explorerId: BigNumberish, itemType: CairoCustomEnum): DojoCall => {
		return {
			contractName: "combat_system",
			entrypoint: "use_item",
			calldata: [explorerId, itemType],
		};
	};

	const combat_system_useItem = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, itemType: CairoCustomEnum) => {
		try {
			return await provider.execute(
				snAccount,
				build_combat_system_useItem_calldata(explorerId, itemType),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_approve_calldata = (to: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "approve",
			calldata: [to, tokenId],
		};
	};

	const explorer_token_approve = async (snAccount: Account | AccountInterface, to: string, tokenId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_approve_calldata(to, tokenId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_availableSupply_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "availableSupply",
			calldata: [],
		};
	};

	const explorer_token_availableSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_availableSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_balanceOf_calldata = (account: string): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "balanceOf",
			calldata: [account],
		};
	};

	const explorer_token_balanceOf = async (account: string) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_balanceOf_calldata(account));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_contractUri_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "contractURI",
			calldata: [],
		};
	};

	const explorer_token_contractUri = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_contractUri_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_defaultRoyalty_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "defaultRoyalty",
			calldata: [],
		};
	};

	const explorer_token_defaultRoyalty = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_defaultRoyalty_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_getApproved_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "getApproved",
			calldata: [tokenId],
		};
	};

	const explorer_token_getApproved = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_getApproved_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_isApprovedForAll_calldata = (owner: string, operator: string): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "isApprovedForAll",
			calldata: [owner, operator],
		};
	};

	const explorer_token_isApprovedForAll = async (owner: string, operator: string) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_isApprovedForAll_calldata(owner, operator));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_isMintedOut_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "is_minted_out",
			calldata: [],
		};
	};

	const explorer_token_isMintedOut = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_isMintedOut_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_isMintingPaused_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "is_minting_paused",
			calldata: [],
		};
	};

	const explorer_token_isMintingPaused = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_isMintingPaused_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_isOwnerOf_calldata = (address: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "is_owner_of",
			calldata: [address, tokenId],
		};
	};

	const explorer_token_isOwnerOf = async (address: string, tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_isOwnerOf_calldata(address, tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_lastTokenId_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "last_token_id",
			calldata: [],
		};
	};

	const explorer_token_lastTokenId = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_lastTokenId_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_maxSupply_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "maxSupply",
			calldata: [],
		};
	};

	const explorer_token_maxSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_maxSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_mintExplorer_calldata = (explorerClass: CairoCustomEnum): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "mint_explorer",
			calldata: [explorerClass],
		};
	};

	const explorer_token_mintExplorer = async (snAccount: Account | AccountInterface, explorerClass: CairoCustomEnum) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_mintExplorer_calldata(explorerClass),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_mintedSupply_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "mintedSupply",
			calldata: [],
		};
	};

	const explorer_token_mintedSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_mintedSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_name_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "name",
			calldata: [],
		};
	};

	const explorer_token_name = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_name_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_ownerOf_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "ownerOf",
			calldata: [tokenId],
		};
	};

	const explorer_token_ownerOf = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_ownerOf_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_reservedSupply_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "reservedSupply",
			calldata: [],
		};
	};

	const explorer_token_reservedSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_reservedSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_rest_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "rest",
			calldata: [explorerId],
		};
	};

	const explorer_token_rest = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_rest_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_royaltyInfo_calldata = (tokenId: BigNumberish, salePrice: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "royaltyInfo",
			calldata: [tokenId, salePrice],
		};
	};

	const explorer_token_royaltyInfo = async (tokenId: BigNumberish, salePrice: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_royaltyInfo_calldata(tokenId, salePrice));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_safeTransferFrom_calldata = (from: string, to: string, tokenId: BigNumberish, data: Array<BigNumberish>): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "safeTransferFrom",
			calldata: [from, to, tokenId, data],
		};
	};

	const explorer_token_safeTransferFrom = async (snAccount: Account | AccountInterface, from: string, to: string, tokenId: BigNumberish, data: Array<BigNumberish>) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_safeTransferFrom_calldata(from, to, tokenId, data),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_setApprovalForAll_calldata = (operator: string, approved: boolean): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "setApprovalForAll",
			calldata: [operator, approved],
		};
	};

	const explorer_token_setApprovalForAll = async (snAccount: Account | AccountInterface, operator: string, approved: boolean) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_setApprovalForAll_calldata(operator, approved),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_supportsInterface_calldata = (interfaceId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "supports_interface",
			calldata: [interfaceId],
		};
	};

	const explorer_token_supportsInterface = async (interfaceId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_supportsInterface_calldata(interfaceId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_symbol_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "symbol",
			calldata: [],
		};
	};

	const explorer_token_symbol = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_symbol_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_tokenRoyalty_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "tokenRoyalty",
			calldata: [tokenId],
		};
	};

	const explorer_token_tokenRoyalty = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_tokenRoyalty_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_tokenUri_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "tokenURI",
			calldata: [tokenId],
		};
	};

	const explorer_token_tokenUri = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_tokenUri_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_tokenExists_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "token_exists",
			calldata: [tokenId],
		};
	};

	const explorer_token_tokenExists = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_tokenExists_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_totalSupply_calldata = (): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "totalSupply",
			calldata: [],
		};
	};

	const explorer_token_totalSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_explorer_token_totalSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_explorer_token_transferFrom_calldata = (from: string, to: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "explorer_token",
			entrypoint: "transferFrom",
			calldata: [from, to, tokenId],
		};
	};

	const explorer_token_transferFrom = async (snAccount: Account | AccountInterface, from: string, to: string, tokenId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_explorer_token_transferFrom_calldata(from, to, tokenId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_approve_calldata = (to: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "approve",
			calldata: [to, tokenId],
		};
	};

	const temple_token_approve = async (snAccount: Account | AccountInterface, to: string, tokenId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_approve_calldata(to, tokenId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_availableSupply_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "availableSupply",
			calldata: [],
		};
	};

	const temple_token_availableSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_availableSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_balanceOf_calldata = (account: string): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "balanceOf",
			calldata: [account],
		};
	};

	const temple_token_balanceOf = async (account: string) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_balanceOf_calldata(account));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_contractUri_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "contractURI",
			calldata: [],
		};
	};

	const temple_token_contractUri = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_contractUri_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_defaultRoyalty_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "defaultRoyalty",
			calldata: [],
		};
	};

	const temple_token_defaultRoyalty = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_defaultRoyalty_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_disarmTrap_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "disarm_trap",
			calldata: [explorerId],
		};
	};

	const temple_token_disarmTrap = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_disarmTrap_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_enterTemple_calldata = (explorerId: BigNumberish, templeId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "enter_temple",
			calldata: [explorerId, templeId],
		};
	};

	const temple_token_enterTemple = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, templeId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_enterTemple_calldata(explorerId, templeId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_exitTemple_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "exit_temple",
			calldata: [explorerId],
		};
	};

	const temple_token_exitTemple = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_exitTemple_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_getApproved_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "getApproved",
			calldata: [tokenId],
		};
	};

	const temple_token_getApproved = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_getApproved_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_isApprovedForAll_calldata = (owner: string, operator: string): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "isApprovedForAll",
			calldata: [owner, operator],
		};
	};

	const temple_token_isApprovedForAll = async (owner: string, operator: string) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_isApprovedForAll_calldata(owner, operator));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_isMintedOut_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "is_minted_out",
			calldata: [],
		};
	};

	const temple_token_isMintedOut = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_isMintedOut_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_isMintingPaused_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "is_minting_paused",
			calldata: [],
		};
	};

	const temple_token_isMintingPaused = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_isMintingPaused_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_isOwnerOf_calldata = (address: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "is_owner_of",
			calldata: [address, tokenId],
		};
	};

	const temple_token_isOwnerOf = async (address: string, tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_isOwnerOf_calldata(address, tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_lastTokenId_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "last_token_id",
			calldata: [],
		};
	};

	const temple_token_lastTokenId = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_lastTokenId_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_lootFallen_calldata = (explorerId: BigNumberish, fallenIndex: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "loot_fallen",
			calldata: [explorerId, fallenIndex],
		};
	};

	const temple_token_lootFallen = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, fallenIndex: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_lootFallen_calldata(explorerId, fallenIndex),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_lootTreasure_calldata = (explorerId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "loot_treasure",
			calldata: [explorerId],
		};
	};

	const temple_token_lootTreasure = async (snAccount: Account | AccountInterface, explorerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_lootTreasure_calldata(explorerId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_maxSupply_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "maxSupply",
			calldata: [],
		};
	};

	const temple_token_maxSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_maxSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_mintTemple_calldata = (difficulty: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "mint_temple",
			calldata: [difficulty],
		};
	};

	const temple_token_mintTemple = async (snAccount: Account | AccountInterface, difficulty: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_mintTemple_calldata(difficulty),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_mintedSupply_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "mintedSupply",
			calldata: [],
		};
	};

	const temple_token_mintedSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_mintedSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_moveToChamber_calldata = (explorerId: BigNumberish, exitIndex: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "move_to_chamber",
			calldata: [explorerId, exitIndex],
		};
	};

	const temple_token_moveToChamber = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, exitIndex: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_moveToChamber_calldata(explorerId, exitIndex),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_name_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "name",
			calldata: [],
		};
	};

	const temple_token_name = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_name_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_openExit_calldata = (explorerId: BigNumberish, exitIndex: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "open_exit",
			calldata: [explorerId, exitIndex],
		};
	};

	const temple_token_openExit = async (snAccount: Account | AccountInterface, explorerId: BigNumberish, exitIndex: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_openExit_calldata(explorerId, exitIndex),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_ownerOf_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "ownerOf",
			calldata: [tokenId],
		};
	};

	const temple_token_ownerOf = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_ownerOf_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_reservedSupply_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "reservedSupply",
			calldata: [],
		};
	};

	const temple_token_reservedSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_reservedSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_royaltyInfo_calldata = (tokenId: BigNumberish, salePrice: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "royaltyInfo",
			calldata: [tokenId, salePrice],
		};
	};

	const temple_token_royaltyInfo = async (tokenId: BigNumberish, salePrice: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_royaltyInfo_calldata(tokenId, salePrice));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_safeTransferFrom_calldata = (from: string, to: string, tokenId: BigNumberish, data: Array<BigNumberish>): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "safeTransferFrom",
			calldata: [from, to, tokenId, data],
		};
	};

	const temple_token_safeTransferFrom = async (snAccount: Account | AccountInterface, from: string, to: string, tokenId: BigNumberish, data: Array<BigNumberish>) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_safeTransferFrom_calldata(from, to, tokenId, data),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_setApprovalForAll_calldata = (operator: string, approved: boolean): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "setApprovalForAll",
			calldata: [operator, approved],
		};
	};

	const temple_token_setApprovalForAll = async (snAccount: Account | AccountInterface, operator: string, approved: boolean) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_setApprovalForAll_calldata(operator, approved),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_supportsInterface_calldata = (interfaceId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "supports_interface",
			calldata: [interfaceId],
		};
	};

	const temple_token_supportsInterface = async (interfaceId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_supportsInterface_calldata(interfaceId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_symbol_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "symbol",
			calldata: [],
		};
	};

	const temple_token_symbol = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_symbol_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_tokenRoyalty_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "tokenRoyalty",
			calldata: [tokenId],
		};
	};

	const temple_token_tokenRoyalty = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_tokenRoyalty_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_tokenUri_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "tokenURI",
			calldata: [tokenId],
		};
	};

	const temple_token_tokenUri = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_tokenUri_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_tokenExists_calldata = (tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "token_exists",
			calldata: [tokenId],
		};
	};

	const temple_token_tokenExists = async (tokenId: BigNumberish) => {
		try {
			return await provider.call("d20_0_1", build_temple_token_tokenExists_calldata(tokenId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_totalSupply_calldata = (): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "totalSupply",
			calldata: [],
		};
	};

	const temple_token_totalSupply = async () => {
		try {
			return await provider.call("d20_0_1", build_temple_token_totalSupply_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_temple_token_transferFrom_calldata = (from: string, to: string, tokenId: BigNumberish): DojoCall => {
		return {
			contractName: "temple_token",
			entrypoint: "transferFrom",
			calldata: [from, to, tokenId],
		};
	};

	const temple_token_transferFrom = async (snAccount: Account | AccountInterface, from: string, to: string, tokenId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_temple_token_transferFrom_calldata(from, to, tokenId),
				"d20_0_1",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};



	return {
		combat_system: {
			attack: combat_system_attack,
			buildAttackCalldata: build_combat_system_attack_calldata,
			castSpell: combat_system_castSpell,
			buildCastSpellCalldata: build_combat_system_castSpell_calldata,
			cunningAction: combat_system_cunningAction,
			buildCunningActionCalldata: build_combat_system_cunningAction_calldata,
			flee: combat_system_flee,
			buildFleeCalldata: build_combat_system_flee_calldata,
			secondWind: combat_system_secondWind,
			buildSecondWindCalldata: build_combat_system_secondWind_calldata,
			useItem: combat_system_useItem,
			buildUseItemCalldata: build_combat_system_useItem_calldata,
		},
		explorer_token: {
			approve: explorer_token_approve,
			buildApproveCalldata: build_explorer_token_approve_calldata,
			availableSupply: explorer_token_availableSupply,
			buildAvailableSupplyCalldata: build_explorer_token_availableSupply_calldata,
			balanceOf: explorer_token_balanceOf,
			buildBalanceOfCalldata: build_explorer_token_balanceOf_calldata,
			contractUri: explorer_token_contractUri,
			buildContractUriCalldata: build_explorer_token_contractUri_calldata,
			defaultRoyalty: explorer_token_defaultRoyalty,
			buildDefaultRoyaltyCalldata: build_explorer_token_defaultRoyalty_calldata,
			getApproved: explorer_token_getApproved,
			buildGetApprovedCalldata: build_explorer_token_getApproved_calldata,
			isApprovedForAll: explorer_token_isApprovedForAll,
			buildIsApprovedForAllCalldata: build_explorer_token_isApprovedForAll_calldata,
			isMintedOut: explorer_token_isMintedOut,
			buildIsMintedOutCalldata: build_explorer_token_isMintedOut_calldata,
			isMintingPaused: explorer_token_isMintingPaused,
			buildIsMintingPausedCalldata: build_explorer_token_isMintingPaused_calldata,
			isOwnerOf: explorer_token_isOwnerOf,
			buildIsOwnerOfCalldata: build_explorer_token_isOwnerOf_calldata,
			lastTokenId: explorer_token_lastTokenId,
			buildLastTokenIdCalldata: build_explorer_token_lastTokenId_calldata,
			maxSupply: explorer_token_maxSupply,
			buildMaxSupplyCalldata: build_explorer_token_maxSupply_calldata,
			mintExplorer: explorer_token_mintExplorer,
			buildMintExplorerCalldata: build_explorer_token_mintExplorer_calldata,
			mintedSupply: explorer_token_mintedSupply,
			buildMintedSupplyCalldata: build_explorer_token_mintedSupply_calldata,
			name: explorer_token_name,
			buildNameCalldata: build_explorer_token_name_calldata,
			ownerOf: explorer_token_ownerOf,
			buildOwnerOfCalldata: build_explorer_token_ownerOf_calldata,
			reservedSupply: explorer_token_reservedSupply,
			buildReservedSupplyCalldata: build_explorer_token_reservedSupply_calldata,
			rest: explorer_token_rest,
			buildRestCalldata: build_explorer_token_rest_calldata,
			royaltyInfo: explorer_token_royaltyInfo,
			buildRoyaltyInfoCalldata: build_explorer_token_royaltyInfo_calldata,
			safeTransferFrom: explorer_token_safeTransferFrom,
			buildSafeTransferFromCalldata: build_explorer_token_safeTransferFrom_calldata,
			setApprovalForAll: explorer_token_setApprovalForAll,
			buildSetApprovalForAllCalldata: build_explorer_token_setApprovalForAll_calldata,
			supportsInterface: explorer_token_supportsInterface,
			buildSupportsInterfaceCalldata: build_explorer_token_supportsInterface_calldata,
			symbol: explorer_token_symbol,
			buildSymbolCalldata: build_explorer_token_symbol_calldata,
			tokenRoyalty: explorer_token_tokenRoyalty,
			buildTokenRoyaltyCalldata: build_explorer_token_tokenRoyalty_calldata,
			tokenUri: explorer_token_tokenUri,
			buildTokenUriCalldata: build_explorer_token_tokenUri_calldata,
			tokenExists: explorer_token_tokenExists,
			buildTokenExistsCalldata: build_explorer_token_tokenExists_calldata,
			totalSupply: explorer_token_totalSupply,
			buildTotalSupplyCalldata: build_explorer_token_totalSupply_calldata,
			transferFrom: explorer_token_transferFrom,
			buildTransferFromCalldata: build_explorer_token_transferFrom_calldata,
		},
		temple_token: {
			approve: temple_token_approve,
			buildApproveCalldata: build_temple_token_approve_calldata,
			availableSupply: temple_token_availableSupply,
			buildAvailableSupplyCalldata: build_temple_token_availableSupply_calldata,
			balanceOf: temple_token_balanceOf,
			buildBalanceOfCalldata: build_temple_token_balanceOf_calldata,
			contractUri: temple_token_contractUri,
			buildContractUriCalldata: build_temple_token_contractUri_calldata,
			defaultRoyalty: temple_token_defaultRoyalty,
			buildDefaultRoyaltyCalldata: build_temple_token_defaultRoyalty_calldata,
			disarmTrap: temple_token_disarmTrap,
			buildDisarmTrapCalldata: build_temple_token_disarmTrap_calldata,
			enterTemple: temple_token_enterTemple,
			buildEnterTempleCalldata: build_temple_token_enterTemple_calldata,
			exitTemple: temple_token_exitTemple,
			buildExitTempleCalldata: build_temple_token_exitTemple_calldata,
			getApproved: temple_token_getApproved,
			buildGetApprovedCalldata: build_temple_token_getApproved_calldata,
			isApprovedForAll: temple_token_isApprovedForAll,
			buildIsApprovedForAllCalldata: build_temple_token_isApprovedForAll_calldata,
			isMintedOut: temple_token_isMintedOut,
			buildIsMintedOutCalldata: build_temple_token_isMintedOut_calldata,
			isMintingPaused: temple_token_isMintingPaused,
			buildIsMintingPausedCalldata: build_temple_token_isMintingPaused_calldata,
			isOwnerOf: temple_token_isOwnerOf,
			buildIsOwnerOfCalldata: build_temple_token_isOwnerOf_calldata,
			lastTokenId: temple_token_lastTokenId,
			buildLastTokenIdCalldata: build_temple_token_lastTokenId_calldata,
			lootFallen: temple_token_lootFallen,
			buildLootFallenCalldata: build_temple_token_lootFallen_calldata,
			lootTreasure: temple_token_lootTreasure,
			buildLootTreasureCalldata: build_temple_token_lootTreasure_calldata,
			maxSupply: temple_token_maxSupply,
			buildMaxSupplyCalldata: build_temple_token_maxSupply_calldata,
			mintTemple: temple_token_mintTemple,
			buildMintTempleCalldata: build_temple_token_mintTemple_calldata,
			mintedSupply: temple_token_mintedSupply,
			buildMintedSupplyCalldata: build_temple_token_mintedSupply_calldata,
			moveToChamber: temple_token_moveToChamber,
			buildMoveToChamberCalldata: build_temple_token_moveToChamber_calldata,
			name: temple_token_name,
			buildNameCalldata: build_temple_token_name_calldata,
			openExit: temple_token_openExit,
			buildOpenExitCalldata: build_temple_token_openExit_calldata,
			ownerOf: temple_token_ownerOf,
			buildOwnerOfCalldata: build_temple_token_ownerOf_calldata,
			reservedSupply: temple_token_reservedSupply,
			buildReservedSupplyCalldata: build_temple_token_reservedSupply_calldata,
			royaltyInfo: temple_token_royaltyInfo,
			buildRoyaltyInfoCalldata: build_temple_token_royaltyInfo_calldata,
			safeTransferFrom: temple_token_safeTransferFrom,
			buildSafeTransferFromCalldata: build_temple_token_safeTransferFrom_calldata,
			setApprovalForAll: temple_token_setApprovalForAll,
			buildSetApprovalForAllCalldata: build_temple_token_setApprovalForAll_calldata,
			supportsInterface: temple_token_supportsInterface,
			buildSupportsInterfaceCalldata: build_temple_token_supportsInterface_calldata,
			symbol: temple_token_symbol,
			buildSymbolCalldata: build_temple_token_symbol_calldata,
			tokenRoyalty: temple_token_tokenRoyalty,
			buildTokenRoyaltyCalldata: build_temple_token_tokenRoyalty_calldata,
			tokenUri: temple_token_tokenUri,
			buildTokenUriCalldata: build_temple_token_tokenUri_calldata,
			tokenExists: temple_token_tokenExists,
			buildTokenExistsCalldata: build_temple_token_tokenExists_calldata,
			totalSupply: temple_token_totalSupply,
			buildTotalSupplyCalldata: build_temple_token_totalSupply_calldata,
			transferFrom: temple_token_transferFrom,
			buildTransferFromCalldata: build_temple_token_transferFrom_calldata,
		},
	};
}