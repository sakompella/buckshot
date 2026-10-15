import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";

// Throwaway prototype: a scripted "agent" in its own process. It knows only its
// own seat URL. It plays to the end with a fixed policy, probes the seat's
// limits, and prints one JSON summary line on stdout for the referee.

const flag = (name: string): string => {
  const index = process.argv.indexOf(`--${name}`);
  const value = process.argv[index + 1];
  if (index === -1 || value === undefined) throw new Error(`--${name} is required`);
  return value;
};

const url = flag("url");
const transport = flag("transport");
const base = flag("base");

interface View {
  readonly you: number;
  readonly status: "your turn" | "waiting" | "over";
  readonly turn?: number;
  readonly events?: ReadonlyArray<string>;
  readonly moves?: ReadonlyArray<string>;
}

interface Reply { readonly text: string; readonly isError: boolean }

const viaJson = async (name: string, args: Record<string, unknown>): Promise<Reply> => {
  const response = await fetch(`${url}/call/${name}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(args) });
  return (await response.json()) as Reply;
};

const client = new Client({ name: "arena-proto-agent", version: "0.0.0" });
if (transport === "mcp") await client.connect(new StreamableHTTPClientTransport(new URL(`${url}/mcp`)));

const viaMcp = async (name: string, args: Record<string, unknown>): Promise<Reply> => {
  const result = await client.callTool({ name, arguments: args });
  const first = (result.content as ReadonlyArray<{ type: string; text?: string }>)[0];
  return { text: first?.text ?? "", isError: result.isError === true };
};

const call = transport === "mcp" ? viaMcp : viaJson;

const views: Array<View> = [];
const getView = async (args: Record<string, unknown> = {}): Promise<View> => {
  const reply = await call("get_game", args);
  if (reply.isError) throw new Error(`get_game refused: ${reply.text}`);
  const view = JSON.parse(reply.text) as View;
  views.push(view);
  return view;
};

const first = await getView();
const me = first.you;
const other = me === 1 ? 2 : 1;

const probes: Record<string, boolean> = {};
probes["foreignPlayerArgGivesOwnView"] = (await getView({ player: other })).you === me;
probes["unknownToken404"] = (await fetch(`${base}/seat/${"0".repeat(32)}/call/get_game`, { method: "POST", body: "{}" })).status === 404;
probes["newMatchRefused"] = await (async () => {
  try {
    return (await call("new_match", { players: 2, items: true })).isError;
  } catch {
    return true;
  }
})();

const heard: Array<string> = [];
let moves = 0;
let stale = 0;
let forced = 0;
const forcedLabels: Record<string, number> = {};

for (;;) {
  const view = await getView();
  if (view.status === "over") {
    heard.push(...(view.events ?? []));
    break;
  }
  if (view.status === "waiting") continue;
  const legal = view.moves ?? [];
  const played = await call("play_move", { move: (moves * 5 + 1) % legal.length, turn: view.turn });
  if (played.isError) {
    stale += 1;
    continue;
  }
  heard.push(...(view.events ?? []));
  forced += legal.length === 1 ? 1 : 0;
  if (legal.length === 1) forcedLabels[legal[0] ?? ""] = (forcedLabels[legal[0] ?? ""] ?? 0) + 1;
  moves += 1;
}

probes["allViewsOwn"] = views.every((view) => view.you === me);
if (transport === "mcp") await client.close();
console.log(JSON.stringify({ you: me, moves, stale, forced, forcedLabels, views: views.length, heard, probes }));
