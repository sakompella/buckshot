import { readFileSync } from "node:fs";
import { join } from "node:path";

import type { Plugin } from "vite";

import { decodeFindingsData } from "./data.ts";
import { articleHtml } from "./page.ts";

// The online site's one page. In `--mode online` the HTML Vite serves and builds as index.html is findings.html with
// the article rendered in from summary.json and findings.json in `dataDir`, in place of the arena viewer's index.html,
// so / is the post both under `cf dev` and in the build. A missing or undecodable data file fails the build.

const SLOT = "<!-- findings:article -->";

const read = (dataDir: string, name: string): string => readFileSync(join(dataDir, `${name}.json`), "utf8");

export const findingsPage = (page: string, dataDir: string): Plugin => ({
  name: "findings-page",
  transformIndexHtml: {
    order: "pre",
    handler: () => readFileSync(page, "utf8").replace(SLOT, articleHtml(decodeFindingsData(read(dataDir, "summary"), read(dataDir, "findings")))),
  },
});
