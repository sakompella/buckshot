# Per-entrant instructions

Every player gets the same instructions (`INSTRUCTIONS` in `web/src/arena/match.ts`), so a result compares models, not prompts. One experiment needs the opposite: how much a model's play changes with one added line, such as an immediate-recall prompt, with everything else equal. A tournament entrant may therefore carry an `instructionsAddendum`. The arena appends it after the shared instructions, separated by a blank line, for that entrant's agent only. The other seats keep the shared instructions unchanged.

This is a labelled exception to the equal-prompt rule, not a change to it:
- **The entrant has its own name,** such as `gpt-6-astra-low-recall` beside `gpt-6-astra-low`. Ratings are per entrant, so the two are never pooled.
- **Provenance records the text.** The agent's entry in the manifest's `provenance.agents` carries `instructions_addendum` when the entrant has one, and no such key otherwise. A resume compares each agent's entry, so a changed, added or dropped addendum stops it like any other changed setting (ADR-0039). The tournament runner also leaves out a finished match whose manifest differs from the schedule's addendum.
- **`instructions_sha` stays the hash of the shared instructions.** It is the same for every agent of a match and does not cover addenda. To know what one agent was told, read its own `instructions_addendum`.
- **The addendum is a setting of the agent,** passed to the match as `PLAYER_<letter>_INSTRUCTIONS_ADDENDUM` like its model and effort.
- **An entrant may name the effort analysis files it under** with `effortLabel`. The match still asks the model for `effort`. Astra low with the immediate-recall prompt is filed under `off` (none): Astra rejects reasoning effort none, so this is the nearest it gets. The viewer marks Astra's off config with an asterisk.

## Considered Options

- **A second shared prompt chosen per tournament:** it would change every seat, so the entrant under test could not sit beside the plain one at one table.
- **Hash the full per-agent instructions into provenance:** the text is short and readable, and a hash would need the text to be of any use.
- **Replace the instructions per entrant:** it could change more than the one line under test, and the shared text would no longer show what the entrant was told.

## Consequences

`match.ts` and `endpoints.ts` are part of the code the commit identifies (ADR-0054), so matches from before this change resume only under their own checkout (ADR-0041). Analysis that keys positions on the match's `instructions_sha` alone does not tell an addendum agent from a plain one; use the entrant or the agent's provenance.
