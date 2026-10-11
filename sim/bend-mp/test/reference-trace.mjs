import { readFileSync } from 'node:fs';
import { buildReference, config, round, traceJSON } from './reference-adapter.mjs';

// Input is {name, seats, rounds: [round specs], tape: [Nat...]}. A round can
// include items: {saw: {enabled: true, per_player: 2, on_table: 32}}. Omitted
// rounds use the adapter's fixed one-health, one-live, no-items core fixture.
const input = JSON.parse(readFileSync(process.argv[2] ?? 0, 'utf8'));
const c = config(input.seats, input.rounds?.map(round));
const { R, close } = await buildReference();
try {
  console.log(JSON.stringify(traceJSON(R, input.name ?? 'core', c, input.tape)));
} finally {
  close();
}
