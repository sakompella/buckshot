# Seats are fixed sockets

A seat's identity in the machine is its socket, and it never changes. A table of two uses sockets 1 and 3, three uses 0 to 2, and four uses 0 to 3. Per-seat data lives in rings with one entry per seated socket, so a ring cannot miss a seat or hold an empty one. Seat shuffling and rotation are not in the machine. A driver decides who sits where. Rotation would make every law quantify over permutations. With fixed identity, per-seat lemmas and one turn-traversal lemma are enough. People and agents never see sockets (ADR-0031).

## Consequences

The arena's rotation of agents between matches (ADR-0007) happens outside the machine.
