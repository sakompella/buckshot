import { Exit } from "effect";
import type { Runtime } from "foldkit";
import type { WebMCP } from "webmcp-types";

import { AgentCall, AgentReply, type ports } from "./agent.ts";
import { Seat } from "./domain.ts";
import { Controller } from "./driver.ts";

// Registers the WebMCP tools. Each tool sends one AgentCall into the runtime
// through its inbound port and resolves with the reply the app emits on the
// outbound port, so the tools never read the Model or touch the game. A refusal
// is returned as {"error": ...} text, because Chrome hides a thrown error's message from the agent.

type Handles = Runtime.EmbedHandle<typeof ports>["ports"];

const RULES =
  "Buckshot: a shotgun is loaded with a hidden mix of live and blank shells, and each load is announced. On your turn you shoot a seat or yourself, or use an item; a live shell does damage and a blank fired at yourself keeps your turn. The last seat alive wins the round and its prize, and the most cash after the last round wins.";

const SEAT_INPUT = { type: "integer", enum: Seat.literals, description: "The Agent seat this call is for, as numbered in the seat names (Seat 0 to Seat 3)." } as const;

export const registerAgentTools = (context: WebMCP.ModelContext, handles: Handles): Promise<void> => {
  const waiting = new Map<number, (reply: AgentReply) => void>();
  let lastId = 0;

  handles.agentReplied.subscribe(({ id, reply }) => {
    waiting.get(id)?.(reply);
    waiting.delete(id);
  });

  const call = (request: AgentCall): Promise<string> =>
    new Promise((resolve) => {
      lastId += 1;
      const id = lastId;

      waiting.set(id, (reply) =>
        AgentReply.match(reply, {
          Answered: ({ text }) => resolve(text),
          Refused: ({ reason }) => resolve(JSON.stringify({ error: reason })),
        }),
      );

      const sent = handles.agentCalled.send({ id, call: request });

      if (Exit.isFailure(sent)) {
        waiting.delete(id);
        resolve(JSON.stringify({ error: "The arguments do not match the tool's input schema." }));
      }
    });

  return Promise.all([
    context.registerTool({
      name: "get_game",
      description: `${RULES} Returns your seat's view as JSON: the public board, your private notes, recent events, whether it is your turn, and your legal moves as a numbered list. Only legal moves are listed. Several seats can be Agents; each sees only its own notes.`,
      inputSchema: { type: "object", properties: { seat: SEAT_INPUT }, required: ["seat"] },
      annotations: { readOnlyHint: true },
      execute: ({ seat }) => call(AgentCall.cases.GetGame.make({ seat })),
    }),
    context.registerTool({
      name: "play_move",
      description:
        "Play one of your seat's legal moves, by its number in get_game's moves list. Only legal moves are listed, so any listed number is allowed. Fails if it is not your turn or the turn is stale; any seat's move advances the turn. Returns your seat's new view. The other seats move on their own, so call get_game until isYourTurn is true.",
      inputSchema: {
        type: "object",
        properties: {
          seat: SEAT_INPUT,
          index: { type: "integer", minimum: 0, description: "The index of the move in get_game's moves list." },
          turn: { type: "integer", description: "The turn value from get_game. Pass it so a stale move is refused instead of played." },
        },
        required: ["seat", "index"],
      },
      execute: ({ seat, index, turn }) => call(AgentCall.cases.PlayMove.make({ seat, index, turn })),
    }),
    context.registerTool({
      name: "new_match",
      description:
        "Start a new match. It replaces any match in progress. By default the first seat is the Agent and DoN bots play the others; pass controllers to seat more agents. Returns each seat's number and controller; then call get_game for an Agent seat.",
      inputSchema: {
        type: "object",
        properties: {
          players: { type: "integer", enum: [2, 3, 4], description: "Number of seats at the table." },
          items: { type: "boolean", description: "Whether items are in play." },
          seed: { type: "string", description: "An integer seed for the shell draws, to replay a match. Optional." },
          controllers: {
            type: "array",
            items: { type: "string", enum: Controller.literals },
            description: 'One controller per seat, in seat order, for example ["Agent", "Agent", "DoN"]. Agent seats are played through these tools, DoN and Story are bots, Human seats wait for clicks. Optional.',
          },
        },
        required: ["players", "items"],
      },
      execute: ({ players, items, seed, controllers }) => call(AgentCall.cases.NewMatch.make({ players, items, seed, controllers })),
    }),
  ]).then(() => undefined);
};
