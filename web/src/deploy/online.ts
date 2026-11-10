import { privacyViolations } from "../arena-viewer/privacy.ts";
import { WORKER } from "./worker.ts";

// The checks a Worker version passes at its preview URL before it takes the live domain (ADR-0050). Pure over a
// `fetch`, so they run against the preview, the live site, or a stub.

const ALIAS_PATTERN = /^[a-z][a-z0-9-]*$/;

/** DNS allows 63 characters in the label `<alias>-<worker>`. */
const MAX_ALIAS = 63 - WORKER.length - 1;

/** A preview alias from a label such as a branch name or a date, or undefined when nothing usable is left of it. */
export const aliasOf = (label: string): string | undefined => {
  const alias = label.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^[^a-z]+|-+$/g, "").slice(0, MAX_ALIAS).replace(/-+$/, "");

  return ALIAS_PATTERN.test(alias) ? alias : undefined;
};

export const previewUrl = (alias: string, subdomain: string): string => `https://${alias}-${WORKER}.${subdomain}.workers.dev`;

/** The id `cf workers versions create` prints after an upload. */
export const versionIdOf = (output: string): string | undefined => /Worker Version ID: ([0-9a-f-]{36})/.exec(output)?.[1];

/** The `--versions` value that sends all traffic to one version. */
export const allTraffic = (versionId: string): string => JSON.stringify([{ version_id: versionId, percentage: 100 }]);

/** Pages that must answer with the app shell; the Worker serves every path as the single-page app. */
const PAGES = ["/", "/arena"] as const;

type Fetch = (url: string) => Promise<Response>;

const lines = (what: string, problem: string | undefined): ReadonlyArray<string> => (problem === undefined ? [] : [`${what}: ${problem}`]);

const pageProblem = async (fetcher: Fetch, base: string, path: string): Promise<string | undefined> => {
  const response = await fetcher(base + path);
  const text = await response.text();

  if (response.status !== 200) return `status ${response.status}`;

  return text.includes('<div id="root"') ? undefined : "no app shell";
};

const DATA_FILE = /^data\/([^/]+)\.json$/;

/** The export files in `web/online`, by name, from its files by path. */
export const dataOf = (online: ReadonlyMap<string, string>): ReadonlyMap<string, string> =>
  new Map([...online].flatMap(([path, text]) => {
    const name = DATA_FILE.exec(path)?.[1];

    return name === undefined ? [] : [[name, text] as const];
  }));

/** What stops `web/online` (its files by path) from being uploaded, empty when nothing: a file that is neither `_headers` nor export data, and the privacy check on the data. */
export const uploadProblems = (online: ReadonlyMap<string, string>): ReadonlyArray<string> => [
  ...[...online.keys()].flatMap((path) => (path === "_headers" || DATA_FILE.test(path) ? [] : [`${path}: not part of the site`])),
  ...privacyViolations(dataOf(online)),
];

/** What is wrong with the site at `base`, empty when it may go live. It must serve every file in `local` byte for byte, and they must pass the privacy check. */
export const siteProblems = async (fetcher: Fetch, base: string, local: ReadonlyMap<string, string>): Promise<ReadonlyArray<string>> => {
  const pages = await Promise.all(PAGES.map(async (path) => lines(path, await pageProblem(fetcher, base, path))));
  const served = new Map<string, string>();

  const data = await Promise.all(
    [...local.keys()].map(async (name) => {
      const response = await fetcher(`${base}/data/${name}.json`);
      const text = await response.text();

      if (response.status !== 200 || !(response.headers.get("content-type") ?? "").includes("json")) return [`/data/${name}.json: status ${response.status}, ${response.headers.get("content-type")}`];

      served.set(name, text);

      return lines(`/data/${name}.json`, text === local.get(name) ? undefined : "differs from the exported file");
    }),
  );

  return [...pages.flat(), ...data.flat(), ...privacyViolations(served)];
};
