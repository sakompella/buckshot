# Humans play arena seats from a terminal, over a local socket

A Human seat in an arena match is played from a terminal client, `scripts/arena-human.ts`, connected to a Unix socket the arena opens for that seat. The socket carries only the texts an agent would get and the lines the human types, so the human sees no arena logs and no other seat. Any number of humans can sit, each in their own terminal. The arena stays the only owner of the match: it journals human moves like agent moves, and the delivery cursor, live delivery and the audit work the same way.

## Considered Options

- The arena's own terminal: one human at most, and the arena's output shares the screen.
- The web app's Human controller: there the page owns the table (ADR-0027), so it cannot be a seat in an arena match.
- The arena viewer: the likely next client. It would speak the same socket protocol through a local bridge, and keep no game logic of its own.
