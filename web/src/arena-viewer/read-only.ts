import { Database } from "bun:sqlite";

/** Reads a database file read-only and closes it, also when `read` throws. */
export const readOnly = <A>(path: string, read: (db: Database) => A): A => {
  const db = new Database(path, { readonly: true });

  try {
    return read(db);
  } finally {
    db.close();
  }
};
