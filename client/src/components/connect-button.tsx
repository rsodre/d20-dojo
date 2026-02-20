import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";
import { Button, IconButton } from "@radix-ui/themes";
import { ExitIcon } from "@radix-ui/react-icons";
import { useController } from "@/hooks/use-controller";

export function ConnectButton() {
  const { isConnected, isConnecting } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { username, openProfile } = useController();

  const handleConnect = async () => {
    // connectAsync(); // will not work! need connector
    await connectAsync({ connector: connectors[0] });
  };

  if (isConnected) {
    return (
      <div style={{ display: "flex", gap: "8px" }}>
        <Button variant="soft" onClick={openProfile as any}>
          {username ?? "Profile"}
        </Button>
        <IconButton variant="soft" onClick={() => disconnect()}>
          <ExitIcon />
        </IconButton>
      </div>
    );
  }

  return (
    <Button loading={isConnecting} onClick={handleConnect}>
      Connect
    </Button>
  );
}
