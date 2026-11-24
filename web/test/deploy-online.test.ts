import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";

import { AGGREGATE_NAMES } from "../src/arena-viewer/aggregates.ts";
import { aliasOf, allTraffic, PAGES, previewUrl, siteProblems, uploadProblems, versionIdOf } from "../src/deploy/online.ts";
import { WORKER } from "../src/deploy/worker.ts";
import { FINDINGS_JSON } from "./fixtures.ts";

test("an alias is a DNS-safe label that fits beside the worker name, or nothing", () => {
  hegel.test((tc) => {
    const alias = aliasOf(tc.draw(gs.text()));

    if (alias === undefined) { return; }

    expect(alias).toMatch(/^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$/);
    expect(previewUrl(alias, "me").split(".")[0]?.length).toBeLessThanOrEqual(`https://`.length + 63);
    expect(`${alias}-${WORKER}`.length).toBeLessThanOrEqual(63);
  });
});

test("a branch name becomes an alias", () => {
  expect(aliasOf("site/Deploy_Previews")).toBe(aliasOf("site-deploy-previews"));
  expect(aliasOf("2026-11-04")).toBeUndefined();
  expect(aliasOf("///")).toBeUndefined();
});

test("the version id is read from the upload output, and all traffic goes to it", () => {
  const id = "2900ce08-bf62-44c8-943a-34677b6555c5";

  expect(versionIdOf(`│  Uploaded buckshot (1.84 sec)\n│  Worker Version ID: ${id}\n│`)).toBe(id);
  expect(versionIdOf("nothing")).toBeUndefined();
  expect(JSON.parse(allTraffic(id))).toEqual([{ version_id: id, percentage: 100 }]);
});

const LOCAL = new Map([...AGGREGATE_NAMES, "manifest"].map((name) => [name, `{"${name}":1}`]));

const site = (overrides: Readonly<Record<string, Response>>) => async (url: string) => {
  const path = new URL(url).pathname;
  const page = path === "/" ? new Response("<article></article>", { headers: { "content-type": "text/html" } }) : new Response("<h1>Nothing lives here</h1>", { status: 404, headers: { "content-type": "text/html" } });
  const data = LOCAL.get(path.replaceAll(/^\/data\/|\.json$/g, ""));

  return Promise.resolve(overrides[path] ?? (data === undefined ? page : new Response(data, { headers: { "content-type": "application/json" } })));
};

test("the post answers at / and the arena viewer's old path and any other path answer 404", () => {
  expect(PAGES).toEqual([["/", 200], ["/arena", 404], ["/no-such-page", 404]]);
});

test("a preview that serves the post and the exported data raises no difference or page problem", async () => {
  const problems = await siteProblems(site({}), "https://p.example", LOCAL);

  expect(problems.filter((problem) => /differs|status|article/.test(problem))).toEqual([]);
});

test("a page without the post, an arena still served, a data file that differs and a file that is not JSON are reported", async () => {
  const problems = await siteProblems(
    site({
      "/": new Response('<div id="root"></div>', { headers: { "content-type": "text/html" } }),
      "/arena": new Response("<article></article>", { headers: { "content-type": "text/html" } }),
      "/data/odds.json": new Response("{}", { headers: { "content-type": "application/json" } }),
      "/data/items.json": new Response("<html>", { headers: { "content-type": "text/html" } }),
    }),
    "https://p.example",
    LOCAL,
  );

  expect(problems).toContain("/: no article");
  expect(problems).toContain("/arena: status 200");
  expect(problems).toContain("/data/odds.json: differs from the exported file");
  expect(problems.some((problem) => problem.startsWith("/data/items.json: status 200, text/html"))).toBe(true);
});

test("a file in web/online beside the site's own, its fonts and its data is refused before an upload", () => {
  const online = new Map([
    ["_headers", ""], ["404.html", ""], ["og.png", ""], ["fonts/ebg-400.woff", ""], ["fonts/cousine-700.woff", ""],
    ...[...LOCAL].map(([name, text]) => [`data/${name}.json`, text] as const),
    ["data/private-debug.json", "{}"], ["notes.txt", ""], ["fonts/notes.txt", ""], ["fonts/nested/ebg-400.woff", ""],
  ]);

  const problems = uploadProblems(online);

  expect(problems).toContain("notes.txt: not part of the site");
  expect(problems).toContain("fonts/notes.txt: not part of the site");
  expect(problems).toContain("fonts/nested/ebg-400.woff: not part of the site");
  expect(problems).toContain("private-debug: not an export file");
  expect(problems.filter((problem) => /^(_headers|404\.html|og\.png|fonts\/\w+-\d+\.woff):/.test(problem))).toEqual([]);
});

const withFindings = (findings: string) => uploadProblems(new Map([...[...LOCAL].map(([name, text]) => [`data/${name}.json`, text] as const), ["data/findings.json", findings]]));

test("the findings file is uploaded only when it passes its strict decode", () => {
  expect(withFindings("{}").some((problem) => problem.startsWith("findings:"))).toBe(true);
  expect(withFindings("{}").some((problem) => problem.includes("not an export file"))).toBe(false);
  expect(withFindings(JSON.stringify(FINDINGS_JSON)).filter((problem) => problem.startsWith("findings:"))).toEqual([]);
});
