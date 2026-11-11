# Buckshot

A multiplayer Buckshot table. The rules machine is written in Bend. The table can be played through agent tools and in an arena where models play each other.

## Language

### The table

**Seat**:
The machine's own position at the table. It is never shown to people or agents.
_Avoid_: slot (a slot holds an item)

**Socket**:
The fixed number that identifies a seat inside the machine: 1 and 3 at a table of two, 0 to 2 at three, 0 to 3 at four. It is never shown to people or agents.
_Avoid_: seat number, seat id

**Player A to Player D**:
The name a seat goes by in a match: a letter, from A in table order unless the caller assigns the letters. In the arena, agent A is Player A wherever it sits. Everything shown to people and agents uses it.
_Avoid_: seat number, Player 1

**Controller**:
Who plays a seat: Human, Story, DoN, Agent or, in the arena, Engine (the Rust search at a fixed depth and node budget).

**Bot**:
A seat played by the Story or DoN AI.

**Match**:
Three rounds at one table. The player with the most cash at the end wins.

**Round**:
Play until one player is left alive. That player wins the round's prize.

**Load**:
One filling of the shotgun with a shuffled batch of live and blank shells. A round has several, one each time the gun runs empty. The batch's make-up is public and its order is not.
_Avoid_: round (a round spans several loads)

**Distribution**:
The part of a round when players grab items from the briefcase and place them. It happens at the start of a round and again each time a load runs out.
_Avoid_: handout

**Deal**:
Every random draw from a load running out to the next choice: the item amount, the items each player takes, and the next load's batch and shuffle. The minimax player's expected-deal and sampled reload rules average over the deals, the first over all of them and the second over a random sample.
_Avoid_: distribution (only the items)

### Moving

**Step**:
One answer to the machine's prompt, such as picking up the shotgun.
_Avoid_: action

**Move**:
A whole action a player chooses, such as "Shoot Player B". It is made of one or more steps.
_Avoid_: step, action

**Turn**:
The session's counter. It advances with every accepted move and every new match, and a move names the turn it was chosen at.
_Avoid_: round, token

**View**:
What one player may see at a turn: the board as its screen shows it, its events and its legal moves.
_Avoid_: state, observation

**Event**:
One line of the public match log.

**Secret**:
Something only one player learned, such as what the magnifying glass showed. In the machine it is a note that only that seat hears.

**Log**:
One player's record of the match: every event and that player's own secrets, in order. Each item is a log entry.

### The machine

**Reference**:
The model that follows the real game's scripts function by function. It exists only to check the strong machine.

**Strong machine**:
The rules machine whose steps are the real game's steps, such as picking up the shotgun, then shooting. It offers every seat that may act its legal steps at once. Laws prove it equal to the reference.
_Avoid_: sm (in prose)

**Simple machine**:
The rules machine whose choices are whole moves, offered to one seat at a time. Distribution happens with no choices. Each of its answers is a chain of strong-machine steps.

**Request point**:
A moment when the machine stops and asks its caller: for a draw, for a choice among legal moves, or because the match is finished or stuck. The caller answers with one number.
_Avoid_: prompt (a prompt is one seat's legal moves at a request point)

**Generation**:
The count of answers given in one match. A request point carries its generation with the match's id, so a late answer to an earlier point is refused.
_Avoid_: turn (the session's counter, which a move names)

### The arena

**Agent**:
A player whose moves come through the agent tools instead of clicks or a bot. In the arena an agent is one of A to D, a model on its own endpoint, and plays as the player of its letter.
_Avoid_: bot

**Position**:
A player's place in table order in one match, from 1. Arena logs and seating use it; agents never see it.
_Avoid_: seat (the machine's own)

**Human seat**:
An arena seat a person plays from a terminal, through the terminal client. The person gets the instructions, views and log entries an agent gets, and types a move's number.
_Avoid_: Human controller (in the web app, a person clicking on the page)

**Seating**:
Which agent is at which position in one match. It rotates between matches, together with the bots and Human seats.

**Seed block**:
One seed and every permutation of one pairing's seats, so every entrant sits at every position, and at every place relative to every opponent, equally often. It is 2 matches at two players, 6 at three and 24 at four. A tournament's confidence intervals resample whole seed blocks, because the matches of a block share a seed.
_Avoid_: rotation (cyclic rotations do not give every relative place)

**Forced turn**:
A turn whose only move is "Grab an item". The arena plays it for the agent or human.

**Delivery**:
How a player's log entries reach it in the arena, set when a match starts. With on-turn delivery the new entries come with the player's next turn. With live delivery each change is sent as it happens.

**Fallback move**:
The move the arena plays for an agent that ended its turn without moving, and again after the reminder: one of its legal moves, picked by a hash of the seed, turn and player.

**Reminder**:
The one fixed message an agent gets when it ends its turn without moving: "It is still your turn; call play_move with one of the listed moves."

**Instructions addendum**:
Text a tournament entrant adds after the shared instructions, for its agent only. It is the one way agents' prompts differ, and the entrant is named for it. The match's instructions hash covers the shared instructions only.
_Avoid_: system prompt override

**Provenance**:
What a match records when it starts about what decides its play: the git commit of the checkout, the instructions hash and each agent's endpoint, model, effort, resolved thinking settings and instructions addendum. A resume must bring the same, keys aside.

**Intervention**:
A fallback move, counted against the agent it was played for, because the agent ended its turn without a move even after the arena's one reminder. A reminder alone is not an intervention. A match with an intervention is still scored, and the tournament stats flag it.

**Regret**:
How much a move gave up: the best legal move's score minus the chosen move's, from the minimax player's search over the deciding player's own information, in percentage points of the round win chance. It is exact when both scores are a settled round's win or loss; any other regret is not proven exact, which is not the same as a guess. See `docs/arena/analysis/regret.md`.
_Avoid_: blunder score, error

**Accuracy**:
A config's reader-facing score for its moves, computed as lichess computes accuracy with regret as the drop in win chance: each move is scored from the points of round win chance it gave up, and a game combines a volatility-weighted and a harmonic mean; a config averages its games. 100 is perfect; one decimal on the arena page. The page also shows p99 points lost and inaccuracies, mistakes and blunders per 100 moves (5, 10 and 15 points, lichess's cut-offs). Decisions where every move is within a point are left out. See `docs/arena/analysis/accuracy.md`.
_Avoid_: lost per match, largest missed chance

**Pot share**:
A player's cash at the end of a match divided by all the cash in that match: 1 for a sweep, less when the loser banked round prizes. It is shown beside the rating and is not rated.

**Round share**:
The rounds a player won divided by the rounds it played, where the match's public events give every round winner. Round Elo is a fit on these.

**Config**:
One model on one endpoint at one effort. It is the unit the arena rates and lists, named by its model and effort, such as `claude-opus-5-5-max`; an engine's name is its seat, `Engine/6/20000/sampled`.
_Avoid_: model (a model has many configs), entrant (a tournament's name for a seat to fill, which may carry an instructions addendum)

**Effort**:
The reasoning level requested from a model (off, low, medium, high, xhigh, max). It is what the request asked for, not what the model did: one label spends very different reasoning across providers, and two labels can send the same request.

**Cohort**:
The group of matches the analysis lists and compares together, named in a tournament's config (such as "tournament 8"). The first tournaments' effort sweeps and cross-model games are cohorts too. The leaderboard has one table per cohort, rated on one pooled fit.

**Round Elo**:
The arena's rating: a Bradley-Terry fit over every scored match in which each round is a game, on an Elo scale with its zero set by the fit, per config. The headline number is luck-adjusted, with the luck of each round's chance events (shots, loads and the coin for round 1) taken out. It is not match Elo: +120 here is about +200 on match results. See ADR-0056 and ADR-0058.
_Avoid_: rounds rating, match rating, cash rating (older fits on match results and on pot share, kept in `docs/arena/analysis/matchups.md`)

**Engine anchor**:
An engine seat (`Engine/<depth>/<budget>`) used as a fixed yardstick on the same scale as the models: the Rust search playing the move its own scorer rates best, at a fixed depth and node budget. See ADR-0059.
_Avoid_: bot (the Story and DoN AIs), baseline
