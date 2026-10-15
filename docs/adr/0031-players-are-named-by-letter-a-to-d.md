# Players are named by letter, A to D

People and agents see players as Player A to Player D, in table order unless a caller assigns letters to seats. One module, `web/src/players.ts`, converts between seats and letters. Bend and the driver keep raw seat ids, and every label and tool reply goes through it. These names were Player 1 to Player 4 before. A number changes with where an agent sits, so an arena agent's name would change from match to match. With letters, agent A is Player A wherever it sits, and no socket (ADR-0024) shows. A call for a letter the table does not have is refused.

## Types

A letter is the plain literal type `Letter = "A" | "B" | "C" | "D"`. It is parsed with `Schema.Literals` where text comes in: tool arguments, `.env`, the CLI and run logs. That parse is already strict, so a letter needs no brand and nothing casts to one.

A player at a table is `Player<L extends Letter = Letter>`, like Rust's `Player<A>`: `{ letter: L; seat: Seat }`. Only a `Roster` makes one. `roster.find("A")` returns `Option<Player<"A">>`, so code that knows the letter keeps it in the type, and code that does not uses `Player`. Holding a `Player` proves the table has it, so its seat is a field and not a lookup that can fail. Wire formats, journals and logs carry the `Letter`, never the `Player`, so a seat id cannot leak into a reply.

This replaces a branded `PlayerLetter` string. The brand added nothing the literal union lacked, since the schema is the only way in either way. It also could not say whether the table had the player, so `seatOf` returned an option at every call.

## Considered options

- Only the literal union. It gives the same static guarantee for a known letter, but a letter still says nothing about a table, so every use that needs the seat repeats the lookup.
- A `Player` that wraps only the letter. The same as the union with a field to unwrap.
- A `Roster` parameterised by its letters, so `seatOf` is total for exactly those players. It needs table sizes in the types, and nothing builds a roster from a static size today.
