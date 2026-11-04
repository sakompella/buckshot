import { defineConfig } from "cf/config";

// The online site: the `--mode online` build of the Vite app, served as static assets (ADR-0050). It has no Worker code.
export default defineConfig({
  worker: {
    name: "buckshot",
    compatibilityDate: "2026-11-03",
    assets: { htmlHandling: "auto-trailing-slash", notFoundHandling: "single-page-application" },
    domains: ["buckshot.akompella.dev"],
    workersDev: false,
    previewUrls: true,
  },
});
