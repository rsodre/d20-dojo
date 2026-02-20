import { useMemo } from "react";
import { useMutation } from "@tanstack/react-query";
import { useDojoConfig } from "@/contexts/dojo-config-provider";
import { useAccount } from "@starknet-react/core";
import { Call, CallData } from "starknet";
import { useVrfCall } from "@/hooks/use-vrf";

export const useTempleCalls = () => {
  const { account } = useAccount();
  const { requestRandomCall } = useVrfCall();
  const { profileConfig } = useDojoConfig();
  const contractAddress = profileConfig.contractAddresses.temple;

  const callData = useMemo(() =>
    new CallData(profileConfig.manifest.abis)
  , [profileConfig]);

  const mint_temple = useMutation({
    mutationFn: account?.address ?
      (difficulty: number) => {
        const entrypoint = "mint_temple";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [difficulty]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.mint_temple() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.mint_temple() error:`, error);
    },
  });

  const enter_temple = useMutation({
    mutationFn: account?.address ?
      ({ explorerId, templeId }: { explorerId: bigint; templeId: bigint }) => {
        const entrypoint = "enter_temple";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId, templeId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.enter_temple() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.enter_temple() error:`, error);
    },
  });

  const exit_temple = useMutation({
    mutationFn: account?.address ?
      (explorerId: bigint) => {
        const entrypoint = "exit_temple";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.exit_temple() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.exit_temple() error:`, error);
    },
  });

  const open_exit = useMutation({
    mutationFn: (account?.address && requestRandomCall) ?
      ({ explorerId, exitIndex }: { explorerId: bigint; exitIndex: number }) => {
        const entrypoint = "open_exit";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall(contractAddress),
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerId, exitIndex]),
          },
        ];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.open_exit() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.open_exit() error:`, error);
    },
  });

  const move_to_chamber = useMutation({
    mutationFn: (account?.address && requestRandomCall) ?
      ({ explorerId, exitIndex }: { explorerId: bigint; exitIndex: number }) => {
        const entrypoint = "move_to_chamber";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall(contractAddress),
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerId, exitIndex]),
          },
        ];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.move_to_chamber() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.move_to_chamber() error:`, error);
    },
  });

  const disarm_trap = useMutation({
    mutationFn: (account?.address && requestRandomCall) ?
      (explorerId: bigint) => {
        const entrypoint = "disarm_trap";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall(contractAddress),
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerId]),
          },
        ];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.disarm_trap() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.disarm_trap() error:`, error);
    },
  });

  const loot_treasure = useMutation({
    mutationFn: (account?.address && requestRandomCall) ?
      (explorerId: bigint) => {
        const entrypoint = "loot_treasure";
        const calls: Call[] = [
          // VRF multicall: request_random must be first
          requestRandomCall(contractAddress),
          {
            contractAddress,
            entrypoint,
            calldata: callData.compile(entrypoint, [explorerId]),
          },
        ];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.loot_treasure() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.loot_treasure() error:`, error);
    },
  });

  const loot_fallen = useMutation({
    mutationFn: account?.address ?
      ({ explorerId, fallenIndex }: { explorerId: bigint; fallenIndex: number }) => {
        const entrypoint = "loot_fallen";
        const calls: Call[] = [{
          contractAddress,
          entrypoint,
          calldata: callData.compile(entrypoint, [explorerId, fallenIndex]),
        }];
        return account.execute(calls);
      } : undefined,
    onSuccess: (data) => {
      console.log(`temple.loot_fallen() success tx hash:`, data.transaction_hash);
    },
    onError: (error) => {
      console.log(`temple.loot_fallen() error:`, error);
    },
  });

  return {
    mint_temple,
    enter_temple,
    exit_temple,
    open_exit,
    move_to_chamber,
    disarm_trap,
    loot_treasure,
    loot_fallen,
  };
};
