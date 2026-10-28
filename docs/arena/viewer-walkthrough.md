# Arena viewer walkthrough

A tour of the arena viewer, one section per feature, in page order. Each section says what the feature shows, how to read it, and one thing to look for.

Two copies run on hp-server, both on the tailnet only.

- **Main.** https://hp-server.dog-minnow.ts.net:8443/ is the merged viewer.
- **Preview.** https://hp-server.dog-minnow.ts.net:8444/ runs the `viewer/all-ideas` branch. It is not merged. Sections marked **Preview** exist only there.

Numbers below come from the live pages and from `docs/arena/analysis/`. The data grows, so check a figure against the page before you quote it.

## Page order

Scatter, Interesting, Luck (preview), Seats, Deals (preview), Blunders (preview), Mistakes (preview), Odds (preview), Items (preview), Pressure (preview), Dead rubbers (preview), Reliability, Matches, Leaderboards, Breakdown. The replay opens over the page from a match.

The filter bar under the jump menu applies to the whole page. It has a cohort menu, model chips and effort chips. The "all configs" switch appears only while some config is hidden. The rating toggles described in the next section sit on the scatter, the effort chart, the leaderboards and the breakdown.

## Scatter

### Pooled rating, Wins / Cash / Rounds, Elo / Rank

**Shows.** One point per config, a model at one effort. The y axis is the config's rating. The rating is one Bradley-Terry fit over every completed two-player match of every tournament, so one scale covers every config. Effort sweeps join the others through their medium configs.

**Reading it.**
- Wins / Cash / Rounds picks what the fit counts. Wins counts each match's win share. Cash counts each player's pot share, its cash over the match's cash. Rounds counts every round as one game.
- Elo / Rank switches the y axis between the rating and a place, 1 at the top. The place comes from observed share within a cohort. Under "All cohorts" it comes from the pooled Elo instead.
- The choice carries to the effort chart, the leaderboards and the breakdown.
- Colour is the model. Orange is Claude and blue is GPT. The dashed line joins the frontier, the points no cheaper config beats.
- "Medium only" keeps one point per model.
- Hover or tap a point for its rank, rating, win, pot and round shares, and match count.

**Look for.** Cost and rating are far apart. On cost, Sonnet 5.5 max sits at $3.76 per match with Elo +191. GPT-6 Astra medium costs $0.281 per match for +174. The ratings come from one fit, so read the intervals in the leaderboards before you call a small gap real.

### Axes: Cost, Moves, Tokens, Regret

**Shows.** The x axis, per player per match. The axis switch sits above the chart.

**Reading it.**
- Cost is average dollars, on a log scale.
- Moves is average model moves. They run from about 20 to 32 on the page.
- Tokens is average output tokens, on a log scale, and includes reasoning tokens.
- Regret is mean points of round win chance a move gave up. Lower is better. It appears only when the viewer started with `--regret`.
- Axes span every config, so a filter hides points and never moves the axes.

**Look for.** Tokens spread wider than cost. In the leaderboards Sonnet 5.5 max writes 265k output tokens per match and Astra writes 605. Switch to Regret and the same points line up differently. Sonnet 5.5 max has the lowest regret in the leaderboard, 0.6.

### Effort vs Elo

**Shows.** Does thinking harder help? One line per model across its efforts, left to right from off to max.

**Reading it.** Each dot is a rating. The thin bar through it is the 95% interval. The y axis spans every config, so a filter only adds or removes lines. The Wins / Cash / Rounds and Elo toggles change it. Rank does not.

**Look for.** Opus 5.5 rises with effort, from -1 at low to +98 at medium and +205 at xhigh. GPT-6.1 Sol stays flat. It is +102 at low and +109 at xhigh. Most intervals overlap, so only the large steps count.

### Where the money went

**Preview.** A card under the effort chart.

**Shows.** Each config's share of the total spend.

**Reading it.** One wide bar is split by config, grouped by model, in model colours. A segment wide enough carries its name. Below it, the eight largest configs have their own bars with dollars and share. One line gives the rest. It follows the page filter.

**Look for.** One config takes 39.9% of $1,146. That is Sonnet 5.5 max, at $458. Haiku 5.5 max is next at 9.0%. The other 30 configs share 23.8%.

## Luck (preview)

Three cards that ask how much skill decides a match. Regret stands in for skill, so "played better" means "gave up less win chance".

### Luck vs play

**Shows.** How often the better player wins, and which configs got lucky.

**Reading it.**
- Two big numbers. 38% of 2,471 decided matches, 943, went to the player with the higher mean regret per move. 42% went to the player with the higher total regret.
- "Better play wins more often" bins matches by the regret gap per move. Each bar is the better player's win share, with an interval and the match count.
- "Who got lucky" has one diverging bar per config. The left, dim side is the share of its matches it lost while playing better. The right side is the share it won while playing worse. Rows under 20 matches fade.

**Look for.** The bars climb from 56% for a gap under 0.5 points to 79% at 4 points or more. Even so, about four matches in ten go to the worse player. The per-config bars mostly sit at 15 to 30% on both sides, so they separate little.

### How much skill matters, the upset curve

**Shows.** How often the higher-rated config wins as the rating gap grows.

**Reading it.** Each match between two different ratings is one game. Games are sorted by gap and cut into equal groups. A dot is a group, with its 95% interval. The dashed line is the Bradley-Terry curve for that gap. The chart always uses the win rating.

**Look for.** The higher-rated player won 64% of 2,471 matches. In the widest-gap group, about 310 Elo, it won 86%. The closest group is near a coin flip. The ratings are fitted on these same matches, so the dots sit near the curve by design. The chart shows how wide the spread is. It does not test the ratings on new games.

### Momentum

**Shows.** Whether winning a round makes a config likelier to win the next one.

**Reading it.** One row per config. The filled dot is the chance of winning round 2 after winning round 1. The ring is the chance of winning round 3 after a 1-1 split. The grey tick is the config's overall round share. The axis runs from 0 to 100%.

**Look for.** Mostly noise. Each dot rests on about 40 to 140 trials, which is about 13 points either way. Over all matches, round 2 after a round-1 win is won 49.5% of the time, so there is no general momentum. GPT-6.1 Sol xhigh is the odd row, at 30% after a round-1 win against 54% at 1-1.

## Seats

Table position and round-1 starter charts. These are older than the recent work and are not covered here. The full tables fold under the charts.

## Deals (preview)

### Same deal, different players

**Shows.** Whether the shuffle, not the player, decided the match.

**Reading it.** One row per seed, one column per config, columns sorted by rating. Each cell is two thin bars. The top bar is the config's wins when seated at table position 1 on that deal. The bottom bar is position 2. Lighter means more wins. Blank means it did not play. The left column gives the seed and the share that position 1 won on that deal. Hover a cell for counts. Wide charts scroll sideways.

**Look for.** Some deals favour a seat strongly. Position 1 wins 81% on seed 3004 and 24% on seed 3007. Rows with few configs are old tournaments and look sparse.

## Blunders (preview)

**Shows.** The costliest moves, and how often each config makes one.

**Reading it.**
- Six cards, each a blunder. A card gives the config, the opponent, the move chosen against the best move, and the round win chance before and after. A click opens the replay at that move.
- The bar chart "Moves that gave up 10+ points" gives each config's share of searched moves with regret of 10 points or more. Whiskers are 95% intervals. The best config is on top. The axis is fixed, so a filter only adds or removes bars.
- Without `--regret` the section is empty.

**Look for.** The bars run from 1.7% for Opus 5.5 xhigh to 16.5% for Haiku 4.5 off. All six cards are the same kind of move, a won round thrown away, at 100 points. The bars say more than the cards. Only 85 of 8,813 blunders are proven exact, so most bars rest on search estimates.

## Mistakes (preview)

### Mistakes by shells left

**Shows.** Where in a round the mistakes happen.

**Reading it.** Two panels share one y axis, mean regret per move. The x axis is shells left in the gun, from 1 to 6. The left panel is shots. The right panel is every other move, such as items and steals. One line per model, pooled over efforts. A point on fewer than 30 moves is dropped.

**Look for.** Shots peak at 2 or 3 shells left. Haiku 4.5 reaches about 11 points at 2 shells left. The other moves stay flat between about 1 and 3 for every model. That flat panel is the contrast. Whether the peak is real error or a bias in the search near a reload is covered in `regret.md`.

### Same position, same move

**Shows.** How steady a config is. Given the same position twice, does it choose the same move?

**Reading it.** One row per config, grouped by model, steadiest model first. The dot is the chance that two decisions in the same repeated position chose the same move. The line is a 95% interval. The number at the right is the count of repeated positions. The axis is fixed. It needs the viewer to start with `--knowledge`, and without it the card is not drawn.

**Look for.** The model matters more than the effort. GPT-6 Astra repeats itself about 94% of the time. Sol, Opus and Sonnet sit near 88 to 92%. The Luna and Haiku 4.5 rows sit near 65 to 70%. Most efforts of one model overlap. Repeated positions are mostly early in the match, so this measures steadiness there.

## Odds (preview)

### Playing the odds

**Shows.** Whether a model counts shells. It plots how often a model shoots itself against the chance, by its own count, that the chambered shell is live.

**Reading it.** One line per model, medium effort only. The x bins are 0, 1 to 33, 34 to 49, 50, 51 to 99 and 100% live. The y axis is the share of shots aimed at itself. The dashed grey line is the rule of thumb, which is to shoot yourself when the shell is surely blank and shoot the other player when it is surely live. Shots with a glass or phone clue are left out. A bin under 30 shots is dropped.

**Look for.** At 0% live, a model that counts shells shoots itself 95 to 99% of the time. Luna does it 46% of the time and Haiku 4.5 37%. When the shell is surely live, most models almost never shoot themselves, while Luna still does 14 to 21% of the time.

## Items (preview)

### Item fates

**Shows.** What happened to the items each config received.

**Reading it.** Each bar splits into used, stolen by the opponent, and left unused. The number at the end is the unused share. Unused means discarded at round end or held when the match ended. The left chart has one bar per config, sorted by unused share. The right chart has one bar per item.

**Look for.** The unused share runs from 22% for Luna off to 43% for Haiku 4.5 medium. By item, the inverter is left unused 55% of the time and beer 44%. The magnifying glass is left unused only 15% of the time and the jammer 17%.

## Pressure (preview)

### Thinking under pressure

**Shows.** Whether a model writes less when it is ahead.

**Reading it.** One panel per model, one line per effort. The x axis is the health gap at the move, yours minus the opponent's, from -2 behind to +2 ahead. Gaps beyond that pool into the end points. The y axis is output tokens per move as a multiple of that config's own move at level health, on a log scale. The label at the end of a line gives its tokens per move when level. Points under 30 moves are dropped.

**Look for.** High-effort Claude and Sol lines slope down to the right. Sonnet 5.5 max writes about 1.5 times its level amount at -2 and about half at +2. Astra is flat, at 24 tokens when level. Hard positions are also the losing ones, so this does not prove a model feels pressure.

## Dead rubbers (preview)

**Shows.** Whether a model writes less in round 3 once the match is settled.

**Reading it.** One row per config. The x axis is output tokens per move in round 3, on a log scale. The ring is after a 1-1 split, when round 3 decides. The dot is after one player won both of the first two rounds. The number at the end is the change. Rows are sorted by the drop.

**Look for.** High-effort models write far less once round 3 is dead. Sonnet 5.5 xhigh drops 43% and Haiku 5.5 xhigh 37%. Astra drops 7%. At off, low and medium effort the change is small. Round 3 after a 2-0 lead may also be an easier position, and the chart does not control for it.

## Reliability

The charts of failed calls, faults and the time they cost, one bar per config. They are older and are not covered here, except for the new card below.

### Failed calls by hour

**Preview.** A card under the three bar charts.

**Shows.** When calls failed, which tells outages apart from weak models.

**Reading it.** One lane per model, one bar per hour, in the hour a match started. Every lane shares one height scale, which tops at 50% of replies failing, and one time axis. An hour under 20 replies gets no bar.

**Look for.** Haiku 4.5, Haiku 5.5 and Sonnet 5.5 fail together on Oct 16 and 17 and again on Oct 19, while Opus stays flat. After Oct 20 failures are near zero. The high failure rates in the config bars come from those hours.

## Matches

The newest matches. A row opens the replay. Older than the recent work, so not covered here.

## Leaderboards

### Rating toggles, pot share and round share

**Shows.** One table per cohort, one row per config. The rating column follows the Wins / Cash / Rounds and Elo / Rank toggles above the tables.

**Reading it.**
- Win share is the bar, with its 95% interval.
- Under Cash, a Pot share column appears. It is the config's cash over the match's cash, averaged over its scored matches.
- Under Rounds, a Round share column appears. It is the rounds the config won over the rounds it played.
- Under Elo, the rating column has a 95% interval over seed blocks. Under Rank, it is the place within the cohort, with ties going to the higher Elo.
- A faded row has fewer than 20 scored matches.
- Click a row to see its matches by opponent.

**Look for.** Switching the basis can move a config a lot. Sonnet 5.5 max is +191 on wins, +128 on cash and +129 on rounds. Its pot share is 74%.

### Regret column

**Shows.** The mean points of round win chance a config's moves gave up against the minimax player's best move over its scored matches. Lower is better.

**Reading it.** Hover a cell for the move count and the share proven exact. A dash means no regret was loaded. The column appears only with `--regret`.

**Look for.** Regret agrees with the ratings at the ends. At medium effort the mean regret is 1.1 for Opus and 4.8 for Haiku 4.5, in `regret.md`. The five configs between them overlap in rating and regret does not separate them further.

## Breakdown

The heatmaps, one row per config, with a mode switch. The rating columns follow the same toggles.

### Cell counts

**Shows.** The sample size behind each cell.

**Reading it.** A small grey number sits in the bottom-right corner of every cell, in a short form such as 1.4k. In Win share it counts games against that opponent. In Item use and Choice patterns it counts the moves where the item or pattern was possible. In Play style it counts player-matches.

**Look for.** Many win-share cells rest on 2 games. In the Haiku 5.5 max row a 100% cell has a count of 2, beside a 60% cell with a count of 100. Trust the number before you trust the shade.

### Beats the ratings

**Shows.** Where a config did better or worse than its rating predicts.

**Reading it.** Second in the mode switch. Rows are configs and columns are opponent models. Each cell is the config's observed share against that model minus the share the pooled ratings predict for the same games, in points. A lighter cell beat the prediction. A darker cell fell short. Mid grey is zero. A pair under 10 games shows a dash. The scale ends at plus or minus 15 points. Hover for the observed share, the expected share and the games. It follows the Wins / Cash / Rounds toggle and the filters.

**Look for.** Mostly noise. Most cells sit within 3 points of zero. `matchups.md` found no pair effect worth keeping. A few cells stand out, such as Haiku 4.5 medium at -18 against Sonnet 5.5. They rest on small samples.

## Replay

The replay opens from a match row, an interesting match or a flagged move. The arrow keys step through it. Escape or a click outside closes it.

### Regret tags

**Shows.** How good each model move was.

**Reading it.** Each model move has a tag, "regret" and a number in points. The tag is filled when the move gave up 5 points or more. "Exact" means both scores are settled, a win or a loss. Without it, the score is a search estimate. Open a move to see the best move, both scores, the search depth and whether the node budget stopped it. Moves with no search have no tag.

**Look for.** In one Opus 5.5 xhigh match, Player B used a magnifying glass at 7.6 points of regret. The move panel says the best move was to shoot itself, at 39.0%, and the chosen move scored 31.4%. Most tags in a match read 0.0 and the few big ones carry the match.

### Turning points

**Shows.** The few moves that mattered most.

**Reading it.** On the health chart, every model move that gave up 5 points or more gets a ring on the mover's line, in the seat's colour. A bigger regret gives a bigger ring. The three biggest are filled. They are listed under the chart as "Turning points" chips such as "R2 B · Use magnifying glass · −7.6". A click on a chip or a ring jumps to the move.

**Look for.** In most matches the top three are 6 to 12 points. A match with a 66-point blunder on the last health point shows it plainly. About one match in twelve has nothing above 5 points, so there are no chips.
