import { defineConfig } from "cf/config";

import { WORKER } from "./src/deploy/worker.ts";

// The online site: the `--mode online` build, the static findings post at / and online/404.html for every other path,
// served as static assets. It has no Worker code.
// Its domain is ONLINE_DOMAIN, set with the Cloudflare variables in _work/.cloudflare-deploy.env.
const domain = process.env.ONLINE_DOMAIN;

if (domain === undefined || domain === "") { throw new Error("ONLINE_DOMAIN is not set; load _work/.cloudflare-deploy.env"); }

export default defineConfig({
  worker: {
    name: WORKER,
    compatibilityDate: "2026-11-03",
    assets: { htmlHandling: "auto-trailing-slash", notFoundHandling: "404-page" },
    domains: [domain],
    workersDev: false,
    previewUrls: true,
  },
});
