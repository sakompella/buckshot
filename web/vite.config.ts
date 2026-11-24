import { join } from "node:path";

import { cloudflare } from "@cloudflare/vite-plugin";
import { foldkit } from "@foldkit/vite-plugin";
import { defineConfig } from "vite";

import { findingsPage } from "./src/findings/plugin.ts";

// `--mode online` builds the site Cloudflare serves (cloudflare.config.ts): the static findings post, its figures
// rendered from web/online/data at build time. Any other mode is the local arena viewer.
export default defineConfig(({ mode }) => ({
  plugins: mode === "online" ? [findingsPage(join(import.meta.dirname, "findings.html"), join(import.meta.dirname, "online/data")), cloudflare()] : [foldkit()],
  publicDir: mode === "online" ? "online" : "public",
  // The arena's pages read the arena viewer's API; in development, a viewer on its default port answers them.
  server: { proxy: { "/api": "http://127.0.0.1:8790" } },
}));
