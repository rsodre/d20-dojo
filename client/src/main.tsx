import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { Theme } from "@radix-ui/themes";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ControllerProvider } from "@/contexts/ControllerContext";
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
    <QueryClientProvider client={queryClient}>
      <Theme appearance="dark" accentColor="amber" grayColor="sand" radius="medium">
        <ControllerProvider>
          <App />
        </ControllerProvider>
      </Theme>
    </QueryClientProvider>
  </StrictMode>
);
