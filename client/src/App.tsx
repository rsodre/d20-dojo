import { ConnectButton } from "@/components/ConnectButton";

export default function App() {
  return (
    <div className="min-h-screen">
      <header className="flex items-center justify-between px-6 py-4 border-b border-[var(--gray-6)]">
        <span className="text-xl font-bold tracking-wide text-[var(--amber-9)]">
          D20 On-Chain
        </span>
        <ConnectButton />
      </header>
      <main className="p-6">
        <p className="text-[var(--gray-11)]">Connect your wallet to start playing.</p>
      </main>
    </div>
  );
}
