import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";

import type { Database } from "bun:sqlite";

const REPO = resolve(import.meta.dir, "../../..");

const sha = (text: string): string => createHash("sha256").update(text).digest("hex");

/** import.ts, every local module it imports, directly or not, and the schema it writes: the code that decides what an import validates. */
const importerFiles = (): ReadonlyArray<string> => {
  const transpiler = new Bun.Transpiler({ loader: "ts" });
  const seen = new Set<string>();

  const visit = (path: string): void => {
    if (seen.has(path)) return;
    seen.add(path);

    for (const { path: specifier } of transpiler.scanImports(readFileSync(path, "utf8"))) if (specifier.startsWith(".")) visit(resolve(dirname(path), specifier));
  };

  visit(resolve(import.meta.dir, "import.ts"));

  return [...seen, resolve(import.meta.dir, "schema.sql")].map((path) => relative(REPO, path)).toSorted();
};

/** Each importer file, repository-relative, with its SHA-256. */
export const IMPORTER_FILES: Readonly<Record<string, string>> = Object.fromEntries(importerFiles().map((path) => [path, sha(readFileSync(resolve(REPO, path), "utf8"))]));

/** The importer code hash every validated match is stamped with. */
export const IMPORTER_HASH = sha(JSON.stringify(IMPORTER_FILES));

/** Refuses a database with a match that was validated by other importer, replay or rules code than this checkout's. */
export const assertCurrentImport = (db: Database): void => {
  const stale = db.query<{ name: string; validated_with: string | null }, [string]>("SELECT name, validated_with FROM matches WHERE replay_status = 'validated' AND validated_with IS NOT ? LIMIT 3").all(IMPORTER_HASH);

  if (stale.length > 0) throw new Error(`The analysis database was validated by other replay or rules code (now ${IMPORTER_HASH}); re-import it. Such as: ${JSON.stringify(stale)}`);
};
