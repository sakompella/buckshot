import { rmSync } from "node:fs";
import { createServer, type Socket } from "node:net";
import { createInterface } from "node:readline";

import { Schema } from "effect";

// A human plays an arena seat from a terminal: scripts/arena-human.ts connects
// to the seat's Unix socket. The arena sends the texts an agent would get, one
// JSON line each, and the client answers each turn with one typed line. Nothing
// else crosses the socket, so the human sees no arena logs and no other seat.

/** One message to a human: the text an agent would get, and whether a move is wanted now. */
export const ToHuman = Schema.Struct({ text: Schema.String, expectsMove: Schema.Boolean });

export type ToHuman = typeof ToHuman.Type;

export interface HumanLink {
  readonly send: (message: ToHuman) => Promise<void>;
  /** The next line the human typed, however long that takes. It fails when the terminal goes away. */
  readonly nextLine: () => Promise<string>;
  readonly close: () => void;
}

const linkOver = (socket: Socket): HumanLink => {
  const lines = createInterface({ input: socket })[Symbol.asyncIterator]();

  return {
    send: (message) => new Promise((sent, failed) => socket.write(`${JSON.stringify(message)}\n`, (error) => (error === undefined || error === null ? sent() : failed(error)))),
    nextLine: async () => {
      const next = await lines.next();

      if (next.done === true) throw new Error("the human's terminal went away");

      return next.value;
    },
    close: () => socket.end(),
  };
};

/** Listens on `path` for one terminal. It resolves once listening, so the caller can tell the human where to connect. */
export const listenForHuman = (path: string): Promise<{ readonly connected: Promise<HumanLink> }> =>
  new Promise((listening, failed) => {
    let accept = (_link: HumanLink): void => undefined;

    const connected = new Promise<HumanLink>((resolve) => {
      accept = resolve;
    });

    const server = createServer((socket) => {
      server.close();
      accept(linkOver(socket));
    });

    rmSync(path, { force: true });
    server.once("error", failed);
    server.listen(path, () => listening({ connected }));
  });
