import { Button } from "@radix-ui/themes";
import { useController } from "@/contexts/ControllerContext";

export function ConnectButton() {
  const { isConnected, isConnecting, username, connect, openProfile } =
    useController();

  if (isConnected) {
    return (
      <Button variant="soft" onClick={openProfile}>
        {username ?? "Profile"}
      </Button>
    );
  }

  return (
    <Button loading={isConnecting} onClick={() => void connect()}>
      Connect
    </Button>
  );
}
