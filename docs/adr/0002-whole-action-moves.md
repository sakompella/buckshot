# Whole-action agent moves

The machine asks for one step at a time: pick up the shotgun, then shoot, or use a jammer, then pick whom to jam. An agent instead picks a whole action, such as "Shoot Player B". `src/agent/moves.ts` builds each one by chaining the machine's own legal steps on a copy of the match (ADR-0001). Labels never name a slot. When a player holds two copies of an item, the move uses the first copy, and a drawn item goes in the first free slot, as the DoN AI places it. That is safe because no rule reads a slot index.

## Considered Options

- Exposing the machine's steps directly: twice as many model calls, and states such as "holding the shotgun" that an agent can leave half-done.
- Labels with slots: more moves that differ in nothing that matters to the game.
