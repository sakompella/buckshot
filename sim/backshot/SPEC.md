# Backshot Roulette: behaviour specification

Source: a small single-player move-search bot for the game *Buckshot Roulette* (Dealer vs Player, shared shotgun, items). This document specifies behaviour only. Numbers, orderings and quirks are stated as facts; reproduce them exactly. Everything uses **exact rational arithmetic** (no floats in the search).

## 0. Reference status (read first)

The committed source is broken at its newest commit. A late rename of the unknown-shell counters was not applied to the heuristic code, so move ordering aborts with an "attribute missing" error in almost every non-trivial position. The **reference behaviour** used here is the original with exactly one repair: wherever the heuristics read "live shells / blank shells" they read the unknown-live / unknown-blank counters. Every worked example in section 7 was produced by that repaired original. Examples marked **(unrepaired OK)** give identical output in the unmodified source.

Other aborts that remain in the repaired reference are described in section 6 as **ABORT**. An implementation should report an error value for them (the original raises an exception; there is no catch except the one noted for the GUI). Do not "fix" bugs unless told; section 8 lists discrepancies with the real game for the implementer to check separately.

## 1. Overview

Input: a described position. Output: the recommended move, its evaluation, and the principal line (path).

Parts:
1. **Game model**: a position, the 11 moves, and each move's outcomes (with probabilities).
2. **Search**: depth-limited alpha-beta over positions. Chance outcomes are competing options, not averaged (section 4).
3. **Heuristics**: forced "obvious" moves, redundant-move filter, a move-ordering score, and a terminal estimate.
4. **CLI**: prompts for a position, then runs the search at depths 1..18 and prints each result.
5. **GUI**: a form for a position, a Search button, one depth-18 search, and a text result.

Evaluation sign: **higher is better for the Player**. The Player's turn maximises, the Dealer's turn minimises. Typical values are in [0,1]. The ±1,000,000 sentinel is "no move could be played" (section 4).

### 1.1 CLI
Prompts, in order. Re-prompt rules in brackets.
1. "Is it the players turn? (Y/N)" – player's turn iff the answer starts with y/Y; anything else means the Dealer's turn.
2. Maximum health, Dealer's health, Player's health, # live shells, # blank shells – each re-prompted until the text is all digits.
3. An "Item Key" line (lists only handcuffs, saw, cigarettes, beer, glass).
4. Dealer's items, then Player's items – raw text re-prompted until its length is ≤ 8. Item letters (case-insensitive): h handcuffs, s hand saw, c cigarettes, b beer, m magnifying glass, a adrenaline, e expired medicine, f burner phone, i inverter. Other characters are ignored; order and duplicates are kept.
5. Current shell: starts with l → live, starts with b → blank, otherwise unknown.
6. Handcuff state, must be exactly 0, 1 or 2 (re-prompted).
7. Gun sawed: starts with y/Y.

No other validation (counts vs health, etc.). Then for depth d = 1..18 (no early stop), a fresh search is run. Output per depth:
```
Starting search with depth <d>
<result text>
Searched <N> positions in <seconds> seconds.
```
and finally `Completed search in <seconds> seconds.` Result text is `Move (ValidMoves.<NAME>, Chance dealer kills player: <v*100 to 2 decimals>%)` newline `Path: <names joined by ", ">`. If there is no move (terminal root) it is `Evaluation: <v as decimal float>`. The "chance dealer kills player" label is wrong: v is the Player-favourable value. N is the count of non-terminal nodes visited (section 4); it is deterministic and is used as an acceptance check below.
Move names in `<NAME>`: SHOOT_DEALER, SHOOT_PLAYER, USE_HANDCUFFS, USE_HAND_SAW, USE_CIGARETTES, USE_BEER, USE_MAGNIFYING_GLASS, USE_ADRENALINE, USE_INVERTER, USE_EXPIRED_MEDICINE, USE_BURNER_PHONE.
Path words: dealer, player, handcuff, saw, cigarettes, beer, glass, adrenaline, inverter, medicine, phone.

### 1.2 GUI
Fields: max health 2–5; Dealer health 1–5; Player health 1–5; live 0–4; blank 0–4; two item text boxes; handcuff choice {Not handcuffed=0, Has already skipped turn=1, Has not skipped turn=2}; current shell {Unknown, Live, Blank}; sawed checkbox; player's-turn checkbox (default on). Item text uses the same letters; after conversion only the first 8 items are kept.
Quirks: both health fields are replaced by max(max health, value) (so health is never below max; probably meant min); the current-shell choice is **ignored** (shell is always unknown). Search runs depth 18 and shows `Best Move: <Title name>`, `Evaluation: <v*100, 2 decimals>`, `Path: <words>`. Title names: Shoot Dealer, Shoot Player, Drink Beer, Smoke Cigarettes, Use Hand Saw, Use Handcuffs, Use Magnifying Glass, Use Adrenaline, Use Burner Phone, Use Expired Medicine, Use Inverter. If the root is terminal (no move) it shows "Error when trying to evaluate," newline "check bullet counts or health." (the only caught error). Other errors are uncaught.

## 2. Game model

### 2.1 Position
| Field | Meaning |
|---|---|
| turn | Player or Dealer to move |
| max health, Dealer hp, Player hp | integers |
| L, B | counts of **unknown** live / blank shells (see 3) |
| slots[0..7] | the gun's chamber order; each unknown, live or blank. Slot 0 is the shell that fires next |
| cuffs | 0, 1 or 2 (no record of who is cuffed: it always concerns "the opponent of the mover") |
| sawed | bool |
| adrenaline pending | bool |
| inverter flag | bool (set by inverter, never read except to block reuse) |
| weight | exact rational, starts at 1; product of chance probabilities along the line |
| Dealer items, Player items | lists (duplicates allowed) |

Input position: slot 0 is set from the "current shell"; all other slots unknown. L and B are the totals the user typed (they include the known current shell; the model does not subtract it).

"Removing a shell" = shift slots left by one, appending unknown.

### 2.2 Available moves
Item owner = the mover, except when adrenaline is pending, then it is the **opponent** (stolen items). Candidate list, in this exact order:
adrenaline, beer, burner phone, cigarettes, expired medicine, handcuffs (only if cuffs = 0), hand saw (only if not sawed), inverter, magnifying glass — each included if the owner holds ≥1 of it; then, only if adrenaline is not pending: Player's turn → [shoot-dealer, shoot-player]; Dealer's turn → [shoot-player, shoot-dealer].
Note: the "shoot-dealer" move aims at the Dealer and "shoot-player" at the Player, whoever is the mover (so shooting self = shoot-player on the Player's turn).

### 2.3 The common split
Before any move, compute pl, the probability that the fired/inspected shell is live:
- L+B = 0 → 0; else slot 0 known live → 1; else L/(L+B) (a known **blank** slot 0 is *not* handled: pl stays L/(L+B)).
Live variant: weight×pl, L = max(0, L−1). Blank variant: weight×(1−pl), B = max(0, B−1). Both start as copies of the parent. (Zero-weight variants still exist and are searched.)
"Consume item X" = remove the first X from the item owner's list (an **ABORT** if absent) and clear adrenaline-pending.

### 2.4 Moves → outcomes (list order matters)
| Move | Outcomes (in order) |
|---|---|
| shoot-dealer / shoot-player (target T) | **Live**: T hp = max(0, hp − (2 if sawed else 1)); remove slot 0; sawed=false; if cuffs>0: cuffs−1 and the turn stays, else turn flips. **Blank**: remove slot 0; sawed=false; if cuffs>0: cuffs−1; turn **always becomes T** (regardless of cuffs). |
| beer | Live and Blank variants; remove slot 0 in both; then consume a **magnifying glass** (not a beer!) from the owner: ABORT if the owner has none. |
| magnifying glass | Live variant gets slot 0 = live; Blank variant slot 0 = blank; counts decremented as in 2.3; consume glass. |
| cigarettes | one outcome: mover's hp = max(max health, hp+1) (heals to full; at/above max it grows by 1); consume. Uses the mover (not the stolen-from side) as the one healed. |
| handcuffs | one outcome: cuffs = 2; consume. |
| hand saw | one: sawed = true; consume. |
| adrenaline | one: consume from the **mover's** list, set adrenaline-pending. If already pending: no outcome. |
| inverter | one: set inverter flag; consume. If flag already set: no outcome. It does **not** change any shell. |
| burner phone | total = L+B. For i = 0..total−1, two outcomes: slot i = live, then slot i = blank, each with weight×(1/total) (probabilities sum to 2 per parent, and no count is changed). Consume phone from the owner in each. If i ≥ 8: ABORT. If total = 0: zero outcomes. |
| expired medicine | Outcome 1 ("heal", weight = parent×2/5, **replacing** the weight, L=max(0,L−1)): mover hp = max(max health, hp+2) then −1. Outcome 2 ("bad", weight = parent×3/5, B=max(0,B−1)): mover hp = min(0, hp) = 0 (death). Consume in both. |

Non-shooting moves never change the turn. A move not in the candidate list is invalid (skipped by search, see 4.4). A move with "no outcome" is skipped silently.
Deaths are only noticed by the terminal test; the game never "ends" a line early otherwise (shooting dead players is blocked only because hp=0 is terminal).

## 3. Chance
There is no sampling. Unknown shells are modelled by the counts L, B; each shot/beer/glass draws "live" with probability pl above, as independent draws without memory of earlier slots. Known shells matter only through slot 0 (certain live → pl = 1) and heuristics. Probabilities are carried as the product `weight` and multiplied into the terminal value only. Chance outcomes are **not** averaged: the search treats the live/blank outcomes (and phone/medicine outcomes) as alternatives (section 4).

## 4. Search

### 4.1 Node procedure: search(depth, position, alpha, beta) → (move, value, path)
Initial call: alpha = −1,000,000, beta = +1,000,000 (INF = 1,000,000). Both bounds are passed unchanged to each child and updated locally.

1. **Terminal** if depth = 0, or Player hp = 0, or Dealer hp = 0, or L = 0 (even if the next shell is known live). Value = (1 − K) × Player_hp/(Player_hp + Dealer_hp) × weight, where K is the kill estimate (5.1). Result (no move, value, empty path). Both hp = 0 is ABORT (divide by zero). This node is not counted.
2. Obvious move (5.2). If one exists: move list = [that move], and the redundancy filter is **not** applied. Otherwise move list = ordered moves (5.4) and each is dropped if redundant (5.3).
3. best move starts as shoot-player (Player's turn) / shoot-dealer (Dealer's turn); best value starts at −INF on the Player's turn, +INF on the Dealer's; best path empty.
4. For each move in the list: if it is not a candidate (invalid) or yields no outcomes, skip it. For each outcome in order: child depth = depth − 1 if the move is a shot, else depth. Recurse. Player's turn: if child value > best (strict) take (move, value, child path), then alpha = max(alpha, value). Dealer's turn: strict <, then beta = min(beta, value). After each outcome, if beta ≤ alpha, stop the outcome loop and the move loop.
5. Count this node (positions-searched +1) and return (best move, best value, [best move] + best path).

The mover at a node maximises (Player) or minimises (Dealer) over all outcomes of all moves, so the "chance" outcome set is a free choice for the mover. A zero-weight outcome gives value 0 and so often wins for the Dealer. This is why many values are exactly 0.

If nothing can be searched, the returned value is the initial ±INF with the default move and path = [default move] (e.g. forced move invalid, see 6).
Recommendation = the root's returned move and value. The path is the chain of best moves down the tree (one outcome chosen at each step). Terminal root: no move, value as in step 1.
No transposition table is used (a stub exists but is never called). No time limit. The CLI re-searches from scratch per depth.

## 5. Heuristics and constants

### 5.1 Kill estimate K (terminal value)
Let L,B be the node's unknown counts. If it is the **Dealer's** turn: K = L/(L+B) if B>0 else 1.
If it is the **Player's** turn: take the minimum of three numbers:
- A = (2L−1)/(2(L+B−1)) if L+B−1 > 0, else 1.
- Sf = (1/B) × (1 + Σ_{n=1}^{B−1} (L−1)/(L+B−n)) when B>0 (B=0: Sf = 1). (The sum's denominators are always >0.)
- C = if the mover has a beer candidate: (4L−3)/(4(L+B−2)) when L+B−2>0 else 1; if not: L/(L+B) when B>0 else 1.
Beer is "held" per 2.2 (owner's list, adrenaline-aware).
Values can be negative or above 1 when L = 0 (use exact formula anyway).
Checks: (L,B)=(2,2) Player → 1/2; (3,1) → 3/4; (1,3) → 1/6; Dealer (2,2) → 1/2; (0,2) Player → −1/2.

### 5.2 Obvious move (first match wins; items are the **mover's own list**, ignoring adrenaline)
Let "own hp" be the mover's hp, "shoot other" = the shoot move aimed at the opponent, "shoot self" the other. Note: the "other's health" tested in rule 1 is **always the Dealer's hp**, even on the Dealer's turn (bug).
1. Next shell live (slot 0 live **or** B = 0): if Dealer hp ≥ 2, the mover holds a saw and the gun is not sawed → hand saw; else shoot other.
2. Next shell blank (slot 0 blank **or** L = 0) → shoot self. (Rule 1 is checked first, so slot 0 blank with B = 0 gives rule 1.)
3. Mover holds a glass, slot 0 unknown, L>0 and B>0 → magnifying glass.
4. Mover holds cigarettes and own hp ≠ max health → cigarettes.
5. Mover holds handcuffs and B ≤ 1 → handcuffs (even if cuffs already >0).
else none.
The forced move is searched even if invalid (then skipped; see 6).

### 5.3 Redundant-move filter (non-obvious nodes only)
| Move | Redundant when |
|---|---|
| shoot-dealer | (Dealer's turn and sawed) or (Player's turn and slot 0 blank) or (Dealer's turn and slot 0 live) |
| shoot-player | **always** (see 6) |
| beer, magnifying glass, burner phone | slot 0 known, or L = 0, or B = 0 |
| cigarettes | the **opponent's** hp = max health (bug: not own) |
| hand saw | L = 0 or opponent hp = 1 |
| handcuffs | cuffs > 0 |
| adrenaline | the opponent's item list is empty |
| expired medicine | own hp = max, or (mover holds cigarettes and own hp = max−1) |
| inverter | slot 0 live |

### 5.4 Move ordering
For every candidate move m (2.2 order; including ones the filter will drop): apply it to get outcomes; for each outcome compute predicted score (5.5); the move's key is the **max** over outcomes on the Player's turn, **min** on the Dealer's (start ±INF; a move with no outcomes keeps ±INF; a move that "returns nothing" is omitted). Sort **ascending** by key, stable (ties keep 2.2 order), for both sides. (The documentation says "highest first"; the code does not reverse.) The ordering applies every candidate, so ABORTs in beer/phone/glass moves happen here.

### 5.5 Predicted score of (move, outcome position), "child" = the outcome; "turn" below = the child's turn
score = base + known + other + usage − sawpen − lowpen + 100 × P/(P+D)
- base: −1,000,000 if Player hp = 0, else +1,000,000 if Dealer hp = 0, else 0. (P+D=0 → ABORT.)
- known and other only if L+B ≠ 0 in the child:
  - known: slot 0 live → ±200 (+ for Player's turn, − for Dealer's); then Player's turn and move ≠ shoot-dealer → return −1,000,000 instead; Dealer's turn and move ≠ shoot-player → +1,000,000. Slot 0 blank → ±100; Player's turn and move ≠ shoot-player → −1,000,000; Dealer's turn and move ≠ shoot-dealer → +1,000,000. Unknown → c = L/(L+B); if (Player's turn and move = shoot-dealer) or (Dealer's turn and move = shoot-player) c×100; result c. ("return" replaces the ±200/±100, it is not added to it.)
  - other: only if slot 0 unknown and L/(L+B) ≥ 1/2: if (Player's turn and move = shoot-dealer) or (Dealer's turn and move = shoot-player): 100×(L−B); else 0.
- usage: beer: 250 if slot 0 unknown and L<B else 0. Cigarettes: 150 × (max − hp of the child's-turn side). Saw: 250 if slot 0 live; else 100 if L ≥ B; else 0. Handcuffs: 250 if L+B = 2 else 100. Glass: 2500. All other moves 0.
- sawpen: 150 if (Player's turn, Dealer holds a saw, Player hp ≤ 2) or (Dealer's turn, Player holds a saw, Dealer hp ≤ 2).
- lowpen: 100 if the turn side has hp = 1.
Unused code: a per-item material table and the transposition table, never applied.

## 6. Edge cases and quirks (reasoned)
- **Shoot-player is never searched in non-obvious nodes.** The filter for it returns a pair, which is always truthy; this must be reproduced. So Player never considers shooting self and Dealer never considers shooting the Player except through the obvious-move rules. (Reasoning: clear copy of a "return a, b" typo.)
- **Chance as choice** (4.1) and **weights multiply only at terminals**, so the values are best-single-line weights, not expectations. Alpha-beta on this is order-dependent; keep move order, outcome order, strict comparisons and pruning exact.
- **Beer consumes a magnifying glass.** Any node in which the owner holds a beer and no glass ABORTs (aborts even if the beer would be redundant, because ordering applies every candidate), at any depth of the tree. Positions with obvious moves skip ordering, so they are fine.
- Forced move invalid → nothing searched → value ±INF: e.g. handcuffs forced while cuffs>0 (rule 5, B=1), or any forced shot/saw/cigarette under pending adrenaline.
- Blank known shell: the shot still branches into a live outcome with prob L/(L+B).
- Counts are decremented when a shell is revealed (glass) and again when fired; at L=0 the node is terminal. Revealing the last live shell (L becomes 0) ends the line.
- Cigarettes and medicine heal by max(), not min(): "heal to max", overheal possible. Medicine failure is death; its 2/5 vs 3/5 split replaces the live/blank weights, and it also decrements L (heal) or B (bad).
- Cuffs: with cuffs>0 the shooter keeps the turn after a live shot; the counter goes 2→1→0, so handcuffs (2) give **two** extra live-shot turns, and a cuffs input of 1 gives one. On blank the turn goes to the target regardless.
- Inverter and burner phone are nearly no-op moves (inverter has no shell effect; phone weights sum to 2). Adrenaline: a stolen item acts for the mover but is removed from the opponent's list; a stolen adrenaline has no outcome (skipped).
- Deep searches are cheap: any line ends once L hits 0 or hp 0, so results stop changing after small depths. Depth 18 never limits in practice.
- Item list sizes are not capped by the model (the CLI caps text length 8; the GUI caps items at 8).
- Same-score moves: first in the sorted list wins (strict comparison). Within one move, outcomes later in order win only if strictly better.

## 7. Worked examples (acceptance tests)
Format: position → recommended move, value, path, N (non-terminal nodes counted). Health max/Dealer/Player; L/B; items P=Player, D=Dealer; slot 0; cuffs; sawed. All depth 18 unless said.
1. Player's turn, max 3, hp D3/P3, L1 B1, no items → **shoot-dealer**, **3/10**, path [dealer], N 2.
2. Same, Dealer's turn → shoot-dealer, **0**, path [dealer, player], N 3.
3. Player's turn, 3/3/3, L2 B2, P has glass → **use glass**, **3/10**, path [glass, dealer], N 10.
4. Player's turn, max 4, D2/P3, L3 B1, slot0 live, P has saw → **hand saw**, **1/3**, path [saw, dealer], N 8 **(unrepaired OK)**. Same but sawed → shoot-dealer, 1/3, [dealer], N 7 **(unrepaired OK)**.
5. Player's turn, 3/3/3, L2 B1, P has handcuffs → **handcuffs**, **1/4**, path [handcuff, dealer, dealer], N 6. With L2 B2, cuffs=1 instead → shoot-dealer, 3/16, [dealer, handcuff, dealer], N 9.
6. Player's turn, 3/3/3, L2 B1, P has handcuffs, cuffs=2 → obvious rule 5 invalid → **shoot-player, −1000000, [player], N 1 (unrepaired OK)**.
7. Player's turn, max 3, D3/P2, L2 B2, P has medicine → **medicine**, **2/25**, path [medicine, dealer], N 12.
8. Terminals as the root (value, no move, path empty, N 0, unrepaired OK): Dealer hp 0 with L2 B2, Player's turn, → 1/2. L0 B2, 3/3/3 → 3/4. L2 B2 with depth 0 → 1/4. Dealer hp 0 and Player hp 0 → divide-by-zero ABORT.
9. ABORT: Player's turn, 3/3/3, L2 B2, P has only a beer → error "item not found" (unrepaired OK).
10. Ordering/search: Player's turn, 3/3/3, L2 B2, P has handcuffs and saw. Predicted keys: shoot-dealer 152/3 (outcome scores −269/3 and 152/3), shoot-player 220/3, handcuffs 301/2, saw 301/2. Order: [shoot-dealer, shoot-player, handcuffs, saw] . Search → **handcuffs**, **1/4**, path [handcuff, dealer, saw, dealer], N 39.
11. Extra: L3 B0, 3/3/3, Player's turn, no items → shoot-dealer, 0, [dealer, player, dealer], N 13 **(unrepaired OK)**.

## 8. Possible discrepancies with the real game
- Cigarettes heal to max (and overheal at max) using max() instead of +1 capped at max.
- Expired medicine: 2/5 vs 3/5 probabilities (real game odds may be 50/50), failure = death instead of −1 hp, outcomes also wrongly decrement L/B.
- Beer consumes a glass instead of a beer, and aborts without one.
- Inverter does not flip the shell; burner phone may reveal slot 0 and its outcome weights sum to 2 (real phone reveals one random later shell).
- Handcuffs: counter semantic (two extra shots), the blank-shot turn ignores cuffs, and the model has no owner of cuffs.
- Known-blank slot 0 still branches with live probability; counts of unknown shells include the known slot 0.
- The Dealer's own search is the same minimiser (not the real dealer's AI) and never considers shooting the Player outside the obvious-move rules.
- Obvious-move saw rule requires "Dealer hp ≥ 2" (docs say = 2), and uses Dealer hp even for the Dealer's turn.
- GUI: health forced up to max and the current-shell field ignored.
