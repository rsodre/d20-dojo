import { useAccount, useConnect } from "@starknet-react/core";
import { Button } from "@radix-ui/themes";
import { useController } from "@/hooks/use-controller";

export function ConnectButton() {
  const { isConnected, isConnecting } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { username, openProfile } = useController();

  const handleConnect = async () => {
    // connectAsync(); // will not work! need connector
    await connectAsync({ connector: connectors[0] });
  };

  if (isConnected) {
    return (
      <Button variant="soft" onClick={openProfile as any}>
        {username ?? "Profile"}
      </Button>
    );
  }

  return (
    <Button loading={isConnecting} onClick={handleConnect}>
      Connect
    </Button>
  );
}
