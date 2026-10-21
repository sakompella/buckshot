# Pin each agent to one CPA account for its match

A tournament endpoint can list a non-empty `accounts` pool of CPA auth ids. The runner assigns each agent of that endpoint an account when its match starts. It excludes accounts cooling for that model and prefers the account with the fewest running matches, breaking ties by config order. Running matches count across models because an account can serve several models.

The child receives its pin in `PLAYER_X_CPA_AUTH_ID`, never a command argument. Both provider APIs send `X-CPA-Auth-ID` on every request. The agent's provenance records `cpa_auth_id` and the journal fixes it with the rest of the match configuration, as in ADR-0039. A resume reads that recorded pin, even when another account is available. A match started without pins resumes without pins.

Usage and rate-limit faults cool the model/account pair when the agent is pinned. Other accounts remain available to new matches. If all accounts are cooling, new matches wait until one resets. Unpinned agents retain the existing per-model cooldown and send no account header.

## Why

CPA normally moves requests between upstream accounts. Doing so within a match loses cached context and can break reasoning continuity. Strict account pins keep each match on one upstream account; waiting for that account is preferable to switching it. A per-model cooldown would unnecessarily pause matches on other accounts.

## Consequences

The manifest is the durable source of assignments, not a second assignment file. The match writes its initial running manifest before its first journal commit, so even a crash at that commit leaves the pin available to the runner. The runner holds only current loads and cooldowns in memory, rebuilding them from manifests and fault logs on restart. It still requires one runner per tournament directory. Account pools are part of endpoint configuration and follow the existing tournament growth rules. Unknown or removed CPA ids are provider errors, not a reason to switch accounts. Existing code-version resume rules still apply, as in ADR-0041.
