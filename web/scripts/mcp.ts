import { fromJsonSchema, McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import { Result } from "effect";

import { emptyTable, headlessSession } from "../src/agent/headless.ts";
import { AgentReply, replyText, runTool, tools } from "../src/agent/tools.ts";

// The stdio MCP front end for the agent tools: one headless table per process,
// with the AI seats played in-process. Every Agent seat goes through this one
// connection; another process has its own table. stdout carries JSON-RPC, so
// this logs only to stderr.
// Usage: bun run mcp (an MCP client launches it; see README.md)

let table = emptyTable;

const toolResult = (reply: AgentReply) => ({ content: [{ type: "text" as const, text: replyText(reply) }], isError: AgentReply.guards.Refused(reply) });

serveStdio(() => {
  const server = new McpServer({ name: "buckshot", version: "1.0.0" });

  for (const { name, description, inputSchema, isReadOnly, decodeCall } of tools) {
    server.registerTool(name, { description, inputSchema: fromJsonSchema(inputSchema), annotations: { readOnlyHint: isReadOnly } }, (input) =>
      toolResult(
        Result.match(decodeCall(input), {
          onSuccess: (call) => {
            const outcome = runTool(headlessSession, table, call);

            table = outcome.state;

            return outcome.reply;
          },
          onFailure: (reason) => AgentReply.cases.Refused.make({ reason }),
        }),
      ),
    );
  }

  return server;
});

console.error("buckshot MCP server is listening on stdio");
