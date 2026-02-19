import { useEffect, useState } from "react";
import { useAccount } from "@starknet-react/core";
import type { ControllerConnector } from "@cartridge/connector";

export function useController() {
  const { account, connector } = useAccount();
  const [controller, setController] = useState<ControllerConnector | undefined>();
  const [username, setUsername] = useState<string | undefined>();

  useEffect(() => {
    setController(connector as ControllerConnector);
  }, [connector]);

  useEffect(() => {
    if (controller && account) {
      controller.username()?.then(setUsername);
    } else {
      setUsername(undefined);
    }
  }, [controller, account]);

  return {
    username,
    openProfile: controller?.controller.openProfile,
  };
}
