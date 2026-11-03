import { foldkit } from "@foldkit/vite-plugin";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [foldkit()],
  // The arena's pages read the arena viewer's API; in development, a viewer on its default port answers them.
  server: { proxy: { "/api": "http://127.0.0.1:8790" } },
});
