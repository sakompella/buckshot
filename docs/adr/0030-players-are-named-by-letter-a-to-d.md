# Players are named by letter, A to D

People and agents see players as Player A to Player D, in table order unless a caller assigns letters to seats. One module, `web/src/players.ts`, converts between seats and letters. Bend and the driver keep raw seat ids, and every label and tool reply goes through it. These names were Player 1 to Player 4 before. A number changes with where an agent sits, so an arena agent's name would change from match to match. With letters, agent A is Player A wherever it sits, and no socket (ADR-0023) shows. A call for a letter the table does not have is refused.
