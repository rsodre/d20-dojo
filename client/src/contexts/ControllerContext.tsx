import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import controller from "@/contexts/controller";

type ControllerState = {
  address: string | undefined;
  username: string | undefined;
  isConnected: boolean;
  isConnecting: boolean;
  connect: () => Promise<void>;
  disconnect: () => Promise<void>;
  openProfile: () => void;
};

const ControllerContext = createContext<ControllerState | undefined>(undefined);

async function resolveUsername(): Promise<string | undefined> {
  const result = controller.username();
  return result !== undefined ? result : undefined;
}

export function ControllerProvider({ children }: { children: ReactNode }) {
  const [address, setAddress] = useState<string | undefined>();
  const [username, setUsername] = useState<string | undefined>();
  const [isConnecting, setIsConnecting] = useState(false);

  // Restore existing session on mount without prompting the user.
  useEffect(() => {
    void (async () => {
      const account = await controller.probe();
      if (account) {
        setAddress(account.address);
        setUsername(await resolveUsername());
      }
    })();
  }, []);

  const connect = useCallback(async () => {
    setIsConnecting(true);
    try {
      const account = await controller.connect();
      if (account) {
        setAddress(account.address);
        setUsername(await resolveUsername());
      }
    } finally {
      setIsConnecting(false);
    }
  }, []);

  const disconnect = useCallback(async () => {
    await controller.disconnect();
    setAddress(undefined);
    setUsername(undefined);
  }, []);

  const openProfile = useCallback(() => {
    void controller.openProfile();
  }, []);

  return (
    <ControllerContext.Provider
      value={{
        address,
        username,
        isConnected: !!address,
        isConnecting,
        connect,
        disconnect,
        openProfile,
      }}
    >
      {children}
    </ControllerContext.Provider>
  );
}

export function useController(): ControllerState {
  const ctx = useContext(ControllerContext);
  if (!ctx) throw new Error("useController must be used inside <ControllerProvider>");
  return ctx;
}
