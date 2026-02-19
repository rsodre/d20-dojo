import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import mkcert from "vite-plugin-mkcert";
import wasm from "vite-plugin-wasm";
import { resolve } from "path";

export default defineConfig({
  plugins: [react(), tailwindcss(), mkcert(), wasm()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "./src"),
    },
  },
});
