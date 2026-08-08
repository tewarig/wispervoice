import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  // Relative base: assets resolve correctly on GitHub Pages (/wispervoice/) and any
  // other host or custom domain without a rebuild. Hash routing is unaffected.
  base: "./",
  server: { port: 5173 },
  preview: { port: 4173 },
});
