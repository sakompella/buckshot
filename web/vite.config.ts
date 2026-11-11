import { cloudflare } from "@cloudflare/vite-plugin";
import { foldkit } from "@foldkit/vite-plugin";
import { defineConfig, type Plugin } from "vite";

// The online host serves files, so the app is copied to each page path it has and to the 404 page (cloudflare.config.ts).
const pageCopies: Plugin = {
  name: "page-copies",
  apply: "build",
  enforce: "post",
  generateBundle(_options, bundle) {
    const index = bundle["index.html"];

    if (index?.type !== "asset") return;

    for (const fileName of ["arena.html", "404.html"]) this.emitFile({ type: "asset", fileName, source: index.source });
  },
};

// `--mode online` builds the site Cloudflare serves (cloudflare.config.ts): aggregate JSON from web/online/data, no arena server.
export default defineConfig(({ mode }) => ({
  plugins: [foldkit(), ...(mode === "online" ? [cloudflare(), pageCopies] : [])],
  publicDir: mode === "online" ? "online" : "public",
  // The arena's pages read the arena viewer's API; in development, a viewer on its default port answers them.
  server: { proxy: { "/api": "http://127.0.0.1:8790" } },
}));
