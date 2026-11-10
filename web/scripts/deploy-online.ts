import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";
import { parseArgs } from "node:util";

import { Effect, Schema } from "effect";

import { aliasOf, allTraffic, dataOf, previewUrl, siteProblems, uploadProblems, versionIdOf } from "../src/deploy/online.ts";
import { WORKER } from "../src/deploy/worker.ts";
import { runMain, ScriptError } from "../src/script.ts";

// Deploys the online site in two steps (ADR-0050). Before any upload, `check` refuses a file in web/online that is not
// part of the site and runs the privacy check on the data; `preview` runs it first, and `deploy:online` before its `cf deploy`. `preview` uploads a Worker version without sending it traffic,
// serves it at https://<alias>-buckshot.<workers.dev subdomain>.workers.dev and checks it there. `promote` sends all
// traffic, so $ONLINE_DOMAIN, to a version. Needs CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID and ONLINE_DOMAIN in the
// environment (_work/.cloudflare-deploy.env) and must run under Node 22.23+ for `cf`, as in `nix develop`.

const USAGE = "usage: bun scripts/deploy-online.ts check | preview [--alias <name>] | promote <version id>";

const ONLINE = join(import.meta.dir, "../online");

const API = "https://api.cloudflare.com/client/v4";

const fail = (message: string) => new ScriptError({ message, exitCode: 1 });

const variable = (name: string) => {
  const value = process.env[name];

  return value === undefined || value === "" ? Effect.fail(fail(`${name} is not set; load _work/.cloudflare-deploy.env`)) : Effect.succeed(value);
};

const cf = (...args: ReadonlyArray<string>) =>
  Effect.tryPromise({
    try: async () => {
      const run = Bun.spawn(["node", "node_modules/cf/bin/cf", ...args], { cwd: join(import.meta.dir, ".."), stdout: "pipe", stderr: "pipe" });
      const [out, err, code] = await Promise.all([new Response(run.stdout).text(), new Response(run.stderr).text(), run.exited]);

      if (code !== 0) throw new Error(`cf ${args[0]} ${args[1]} exited ${code}\n${err}${out}`);

      return out + err;
    },
    catch: (error) => fail(String(error)),
  });

const Reply = Schema.Struct({ result: Schema.NullOr(Schema.Struct({ enabled: Schema.optional(Schema.Boolean), previews_enabled: Schema.optional(Schema.Boolean), subdomain: Schema.optional(Schema.String) })) });

const decodeReply = Schema.decodeUnknownEffect(Reply);

const api = (path: string, init?: RequestInit) =>
  Effect.gen(function* () {
    const token = yield* variable("CLOUDFLARE_API_TOKEN");
    const account = yield* variable("CLOUDFLARE_ACCOUNT_ID");
    const response = yield* Effect.tryPromise({ try: () => fetch(`${API}/accounts/${account}${path}`, { ...init, headers: { authorization: `Bearer ${token}`, "content-type": "application/json" } }), catch: (error) => fail(String(error)) });
    const body: unknown = yield* Effect.tryPromise({ try: () => response.json(), catch: (error) => fail(String(error)) });

    if (!response.ok) return yield* Effect.fail(fail(`${path}: ${response.status} ${JSON.stringify(body)}`));

    return (yield* decodeReply(body).pipe(Effect.mapError((error) => fail(`${path}: ${error.message}`)))).result;
  });

/** Version URLs are off until the Worker's workers.dev settings say so; `cf deploy` applies previewUrls, and this does it before the first deploy after it changes. */
const enablePreviews = Effect.gen(function* () {
  const current = yield* api(`/workers/scripts/${WORKER}/subdomain`);

  if (current?.previews_enabled !== true) yield* api(`/workers/scripts/${WORKER}/subdomain`, { method: "POST", body: JSON.stringify({ enabled: current?.enabled ?? false, previews_enabled: true }) });
});

/** Every file Vite copies from web/online into the site, by path. */
const onlineFiles = (): ReadonlyMap<string, string> =>
  new Map(readdirSync(ONLINE, { recursive: true, withFileTypes: true }).filter((entry) => entry.isFile()).map((entry) => {
    const path = join(entry.parentPath, entry.name);

    return [relative(ONLINE, path), readFileSync(path, "utf8")] as const;
  }));

/** The export data, once web/online passes the checks for an upload. */
const check = Effect.gen(function* () {
  const online = onlineFiles();
  const problems = uploadProblems(online);

  return problems.length === 0 ? dataOf(online) : yield* Effect.fail(fail(`web/online must not be uploaded:\n${problems.join("\n")}`));
});

const preview = (label: string) =>
  Effect.gen(function* () {
    const alias = aliasOf(label);

    if (alias === undefined) return yield* Effect.fail(fail(`no usable preview alias in ${JSON.stringify(label)}`));

    const local = yield* check;

    yield* enablePreviews;

    const output = yield* cf("workers", "versions", "create", "--mode", "online", "--preview-alias", alias, "--message", `preview ${alias}`);
    const versionId = versionIdOf(output);

    if (versionId === undefined) return yield* Effect.fail(fail(`no version id in the upload output:\n${output}`));

    const subdomain = (yield* api("/workers/subdomain"))?.subdomain;

    if (subdomain === undefined) return yield* Effect.fail(fail("the account has no workers.dev subdomain"));

    const url = previewUrl(alias, subdomain);
    const problems = yield* Effect.tryPromise({ try: () => siteProblems(fetch, url, local), catch: (error) => fail(String(error)) });

    console.log(JSON.stringify({ versionId, url, problems }));

    return problems.length === 0 ? 0 : yield* Effect.fail(fail(`${url} fails its checks:\n${problems.join("\n")}`));
  });

const promote = (versionId: string) =>
  cf("workers", "deployments", "create", "--worker", WORKER, "--strategy", "percentage", "--versions", allTraffic(versionId)).pipe(Effect.map((output) => console.log(output.trim())));

const program = Effect.gen(function* () {
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options: { alias: { type: "string" } } }), catch: () => fail(USAGE) });
  const [command, version] = parsed.positionals;

  if (command === "check") return yield* check.pipe(Effect.as(0));

  if (command === "preview") return yield* preview(parsed.values.alias ?? `preview-${new Date().toISOString().slice(0, 10)}`);

  if (command === "promote" && version !== undefined) return yield* promote(version);

  return yield* Effect.fail(fail(USAGE));
});

await runMain(program);
