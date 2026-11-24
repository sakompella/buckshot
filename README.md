# Buckshot Arena

Read the findings at [buckshot.akompella.dev](https://buckshot.akompella.dev).

Buckshot Arena is a research project on the two-player shotgun game Buckshot Roulette. It has a formally checked rules library in Bend, a Rust search that scores every move, tools that let an agent play, and an arena where language models play each other. A static site reports the results.

## Findings

- **Scale.** More than 5,000 matches between models, across 45 model configs. A config is one model at one effort setting. Every model move is scored against a depth-7 search.
- **Self-shooting.** When fewer than half the remaining shells are live, strong models shoot themselves on 80% of plain shots. The depth-7 search prefers that on 17%. Reasoning traces show the models read the odds correctly and still lean on the rule that a blank shell keeps the turn.
- **The top is a tie.** Tier 1 holds five model configs, the depth-6 search and the depth-7 search, with no detectable gap between them. In direct rounds against the depth-7 engine, Terra 6.1 at max effort won 95 of 180 and Opus 5.5 at max effort won 46 of 84. Both intervals include 50%. Inside that tier, cost per match spans 37x, from $0.11 to $4.18.
- **Moves beat wins.** Scoring moves needs about 11x fewer seeds than counting wins for the same repeatability. That is why the behavior findings are sharp and the leaderboard is wide.

The post lists its limits. The judge is a depth-7 search, not a solver. The reasoning-trace counts come from a small sample. This is one game.

## The game

Three shells go into the shotgun. Two are blank and one is live, in an order nobody knows. A player aims at an opponent or at themselves. A blank fired at yourself keeps your turn. A live shell costs a life. Items change the odds. A magnifying glass shows the chambered shell, a handsaw doubles the damage, beer ejects a shell, an inverter flips one and a jammer skips the opponent's turn.

The rules cover two to four players, the items, the briefcase grab and the reload.

## How it fits together

Bend is the source of truth for the rules. TypeScript calls Bend exports and never re-implements them. The Rust search is tested against Bend until the two agree on every position in a golden set. When they disagree, Bend wins.

The arena plays seeded matches in both seat orders and logs every model call with its cost and latency. The analysis corrects each round for the luck of the deal and fits a Round Elo with a seed-block bootstrap. It scores each move by the round-win chance the move gave up.

## Repo map

| Path | What it holds |
|-|-|
| `sim/bend-mp/` | The multiplayer rules in Bend 2, the minimax player and the Lean-checked equivalence proofs. |
| `sim/rust/` | The Rust port of the rules and the search, checked against Bend. It scores moves for the arena. |
| `web/` | The TypeScript side. It has the MCP server, the arena runner, the local arena viewer and the static findings site. |
| `tools/arena/` | Python analysis. It covers luck-adjusted ratings, move regret and the self-shooting study. |
| `dev/` | The `dev` command line for heavy jobs and checks. |
| `flake.nix` | The pinned toolchain (Bend, bun, Python, Rust) and the flake checks. |

`CONTEXT.md` defines the domain terms. `AGENTS.md` lists the rules and checks for contributors and coding agents.

## Quickstart

Every command below needs no API key and calls no model. Run them inside the dev shell, which pins Bend 2.0.40, bun, Python and Rust.

    nix develop

Check the Bend equivalence proofs with the Lean-built kernel.

    bend sim/bend-mp/PROOF.bend --verdict

Check that the Rust rules and search agree with Bend.

    bash sim/rust/check.sh

Run the web tests. They cover the rules, the MCP agent contract and the findings site.

    cd web && bun run test

Start the stdio MCP server to play against the built-in bots from an MCP client.

    cd web && bun run mcp

The server offers three tools, `get_game`, `play_move` and `new_match`. `web/README.md` shows how to add it to Claude Code or Codex.

## More checks

Run each of these inside `nix develop`.

Lint and typecheck the TypeScript.

    cd web && bun run lint && bun run typecheck

Run the Rust tests.

    cd sim/rust && cargo test

Run every Bend gate. This is a heavy job.

    bash sim/bend-mp/check.sh

Check the Python tools with ruff, ty and their tests.

    nix build .#checks.x86_64-linux.arena-python

## Running the arena

A real tournament needs provider API keys. From `web/`, `bun scripts/arena-tournament.ts tournaments/example.json --dry-run` prints a schedule without calling a model. `web/README.md` covers the runner, the analysis database and the local arena viewer.

The findings site is a static page built from two data files, `summary.json` and `findings.json`. The files are not in this repository. `web/README.md` describes how they are produced and how to build the page.

## About this project

An unofficial research project, not affiliated with the game's developer. Buckshot Roulette is a game by Mike Klubnika. This repository contains no game assets or copyrighted material.

The code is under the Mozilla Public License 2.0. See `LICENSE.md`.
