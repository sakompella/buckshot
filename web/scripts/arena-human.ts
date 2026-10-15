import { connect } from "node:net";
import { createInterface } from "node:readline";

import { Schema } from "effect";

import { ToHuman } from "../src/arena/human.ts";

// Plays a Human seat of an arena match from this terminal. The arena prints the
// command for each Human seat when the match starts. Each message shows its log
// entries one per line, the rest of the view as JSON, and the moves numbered;
// on your turn, type a move's number and press enter.
// Usage: bun scripts/arena-human.ts <socket>

const decodeMessage = Schema.decodeUnknownSync(Schema.fromJsonString(ToHuman));

const decodeObject = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Record(Schema.String, Schema.Json)));

const Lists = Schema.Struct({ events: Schema.optional(Schema.Array(Schema.String)), moves: Schema.optional(Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String }))), error: Schema.optional(Schema.String) });

/** A message as lines: its heading, its log entries, any error, the rest of its view, then the moves by number. */
const render = (text: string): ReadonlyArray<string> => {
  const at = text.indexOf("{");

  if (at === -1) return [text];

  const heading = text.slice(0, at).trim();
  const shown = decodeObject(text.slice(at));
  const { events = [], moves = [], error } = Schema.decodeUnknownSync(Lists)(shown);
  const rest = Object.fromEntries(Object.entries(shown).filter(([key]) => !["events", "moves", "error"].includes(key)));

  return [
    ...(heading === "" ? [] : [heading]),
    ...events,
    ...(error === undefined ? [] : [`error: ${error}`]),
    ...(Object.keys(rest).length === 0 ? [] : [JSON.stringify(rest)]),
    ...moves.map(({ move, label }) => `${move}. ${label}`),
  ];
};

const path = process.argv[2];

if (path === undefined) throw new Error("Usage: bun scripts/arena-human.ts <socket>");

const socket = connect(path);

const typed = createInterface({ input: process.stdin });

const typedLines = typed[Symbol.asyncIterator]();

for await (const line of createInterface({ input: socket })) {
  const message = decodeMessage(line);

  console.log(render(message.text).join("\n"));

  if (message.expectsMove) {
    process.stdout.write("> ");

    const answer = await typedLines.next();

    if (answer.done === true) break;

    socket.write(`${answer.value}\n`);
  }
}

typed.close();

socket.end();
