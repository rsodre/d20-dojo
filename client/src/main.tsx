import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { Theme } from "@radix-ui/themes";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { DojoConfigProvider } from "@/contexts/dojo-config-provider";
import StarknetProvider from "@/contexts/starknet-provider";
import App from "./App";
import "./index.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5_000,
      refetchOnWindowFocus: false,
    },
  },
});

const root = document.getElementById("root");
if (!root) throw new Error("Root element not found");

createRoot(root).render(
  <StrictMode>
    <BrowserRouter>
      <QueryClientProvider client={queryClient}>
        <Theme appearance="dark" accentColor="amber" grayColor="sand" radius="medium">
          <DojoConfigProvider>
            <StarknetProvider>
              <App />
            </StarknetProvider>
          </DojoConfigProvider>
        </Theme>
      </QueryClientProvider>
    </BrowserRouter>
  </StrictMode>
);
