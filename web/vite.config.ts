import { cloudflare } from "@cloudflare/vite-plugin";
import { foldkit } from "@foldkit/vite-plugin";
import { defineConfig } from "vite";

// `--mode online` builds the site Cloudflare serves (cloudflare.config.ts): aggregate JSON from web/online/data, no arena server.
export default defineConfig(({ mode }) => ({
  plugins: [foldkit(), ...(mode === "online" ? [cloudflare()] : [])],
  ...(mode === "online" ? { publicDir: "online" } : {}),
  // The arena's pages read the arena viewer's API; in development, a viewer on its default port answers them.
  server: { proxy: { "/api": "http://127.0.0.1:8790" } },
}));
