import { Exit, Result, Schema } from "effect";
import { Port, type Runtime } from "foldkit";
import type { WebMCP } from "webmcp-types";

import { AgentCall, AgentReply, replyText, tools } from "./agent/tools.ts";

// The browser front end for the agent tools. Each tool sends its decoded call
// into the runtime through the inbound port and resolves with the reply the app
// emits on the outbound port, so the tools never read the Model or touch the game.

export const ports = {
  inbound: { agentCalled: Port.inbound(Schema.Struct({ id: Schema.Number, call: AgentCall })) },
  outbound: { agentReplied: Port.outbound(Schema.Struct({ id: Schema.Number, reply: AgentReply })) },
};

type Handles = Runtime.EmbedHandle<typeof ports>["ports"];

const refusal = (reason: string): string => replyText(AgentReply.cases.Refused.make({ reason }));

const encodeCall = Schema.encodeSync(AgentCall);

export const registerAgentTools = (context: WebMCP.ModelContext, handles: Handles): Promise<void> => {
  const waiting = new Map<number, (reply: AgentReply) => void>();
  let lastId = 0;

  handles.agentReplied.subscribe(({ id, reply }) => {
    waiting.get(id)?.(reply);
    waiting.delete(id);
  });

  const send = (call: AgentCall): Promise<string> =>
    new Promise((resolve) => {
      lastId += 1;
      const id = lastId;

      waiting.set(id, (reply) => resolve(replyText(reply)));

      if (Exit.isFailure(handles.agentCalled.send({ id, call: encodeCall(call) }))) {
        waiting.delete(id);
        resolve(refusal("The call could not reach the game."));
      }
    });

  return Promise.all(
    tools.map(({ name, description, inputSchema, isReadOnly, decodeCall }) =>
      context.registerTool({
        name,
        description,
        inputSchema,
        annotations: { readOnlyHint: isReadOnly },
        execute: (input) => Result.match(decodeCall(input), { onSuccess: send, onFailure: (reason) => Promise.resolve(refusal(reason)) }),
      }),
    ),
  ).then(() => undefined);
};
