# Quota-limited runs stop for good at a quota line

The model subscriptions are shared with other work, so long arena runs go through `tools/arena/run-quota-limited.sh`. The rules are:

- **Claude:** may use up to 80%. The run doesn't start a pair while the least-used Claude account is at 0.78 or more, and stops when it reaches 0.80 during play. Averaging the accounts would hide an exhausted one, and checking every account would stop on an account that other work used up while another still has room.
- **Codex:** may use its full limit. Each match is pinned to one account (ADR-0042). A full account answers 429, and that pauses only its own matches until the reset.
- **Missing data:** an account with no quota data doesn't block, because CPA keeps quota in memory and loses it on a restart or after a reset until the next reply. An unreadable API does block.
- **Stopping:** on the quota line, a runner failure, a fallback move or failed audit, or the end of the cap, the run stops for good. It doesn't resume after a reset; resuming is the operator's decision.

## Considered Options

- **Pause and resume automatically at each reset.** This keeps using the shared quota with no one deciding to, every time a window resets.
- **One combined average across Claude accounts.** It can drive one account to its limit while it looks safe.
- **Hold Codex to the same line.** Its quota isn't shared the same way, and per-match pins already stop a full account from moving a match mid-game.

## Consequences

A run can stop well before its cap, and an operator restarts it. CPA reports no Claude 7-day window, so that window goes unchecked. A guard that misreads quota data stops a run falsely rather than overspending.
