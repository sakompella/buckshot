# Buckshot

A multiplayer Buckshot table. The rules machine is written in Bend. The table can be played in a browser, through agent tools, and in an arena where models play each other.

## Language

### The table

**Seat**:
The machine's own position at the table. It is never shown to people or agents.
_Avoid_: slot (a slot holds an item)

**Player A to Player D**:
The name a seat goes by in a match: a letter, from A in table order unless the caller assigns the letters. In the arena, agent A is Player A wherever it sits. Everything shown to people and agents uses it.
_Avoid_: seat number, Player 1

**Controller**:
Who plays a seat: Human, Story, DoN or Agent.

**Bot**:
A seat played by the Story or DoN AI.

**Match**:
Three rounds at one table. The player with the most cash at the end wins.

**Round**:
Play until one player is left alive. That player wins the round's prize.

**Distribution**:
The part of a round when players grab items from the briefcase and place them.

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
Something only one player learned, such as what the magnifying glass showed.

**Log**:
One player's record of the match: every event and that player's own secrets, in order. Each item is a log entry.

### The arena

**Agent**:
A player whose moves come through the agent tools instead of clicks or a bot. In the arena an agent is one of A to D, a model on its own endpoint, and plays as the player of its letter.
_Avoid_: bot

**Position**:
A player's place in table order in one match, from 1. Arena logs and seating use it; agents never see it.
_Avoid_: seat (the machine's own)

**Seating**:
Which agent is at which position in one match. It rotates between matches.

**Forced turn**:
A turn whose only move is "Grab an item". The arena plays it for the agent.

**Delivery**:
How a player's log entries reach it in the arena, set when a match starts. With on-turn delivery the new entries come with the player's next turn. With live delivery each change is sent as it happens.

**Fallback move**:
The first legal move. The arena plays it when an agent ends its turn without moving.
