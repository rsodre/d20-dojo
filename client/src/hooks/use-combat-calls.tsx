import { useMemo } from "react";
import { useMutation } from "@tanstack/react-query";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useAccount } from "@starknet-react/core";
import { CairoCustomEnum, Call, CallData } from "starknet";

export const useCombatCalls = () => {
  const { account } = useAccount();
  const { profileConfig } = useDojoConfig();
  const contractAddress = profileConfig.contractAddresses.combat;

  const callData = useMemo(() =>
    new CallData(profileConfig.manifest.abis)
  , [profileConfig]);

  const attack = useMutation({
    mutationFn: account?.address ?
      (explorerId: bigint) => {
        const entrypoint = "attack";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.attack() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.attack() error:`, error);
    },
  });

  const cast_spell = useMutation({
    mutationFn: account?.address ?
      ({ explorerId, spellId }: { explorerId: bigint; spellId: string }) => {
        const spellIdEnum = new CairoCustomEnum({ [spellId]: {} });
        const entrypoint = "cast_spell";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId, spellIdEnum]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.cast_spell() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.cast_spell() error:`, error);
    },
  });

  const use_item = useMutation({
    mutationFn: account?.address ?
      ({ explorerId, itemType }: { explorerId: bigint; itemType: string }) => {
        const itemTypeEnum = new CairoCustomEnum({ [itemType]: {} });
        const entrypoint = "use_item";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId, itemTypeEnum]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.use_item() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.use_item() error:`, error);
    },
  });

  const flee = useMutation({
    mutationFn: account?.address ?
      (explorerId: bigint) => {
        const entrypoint = "flee";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.flee() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.flee() error:`, error);
    },
  });

  const second_wind = useMutation({
    mutationFn: account?.address ?
      (explorerId: bigint) => {
        const entrypoint = "second_wind";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.second_wind() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.second_wind() error:`, error);
    },
  });

  const cunning_action = useMutation({
    mutationFn: account?.address ?
      (explorerId: bigint) => {
        const entrypoint = "cunning_action";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`combat.cunning_action() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`combat.cunning_action() error:`, error);
    },
  });

  return {
    attack,
    cast_spell,
    use_item,
    flee,
    second_wind,
    cunning_action,
  };
};
