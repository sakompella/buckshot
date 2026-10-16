import { Schema } from "effect";

import type { Total } from "../../arena/cost.ts";
import type { CallLine, EventLine } from "../../arena/runlog.ts";
import { type Cursors, type Frame, type JsonlLine, MatchResponse, type PricedCall, type PricedRun, type Run, RunsResponse, type RunSummary } from "../api.ts";
import { afterClick, orderFromQuery, orderRuns, type RunOrder, type SortColumn, writeOrder } from "../order.ts";
import { callsByTurn, type Reasoning, reasoningOf, tokensLabel } from "../reasoning.ts";

// The viewer's page: the list of runs at "/", one match at "/match/<id>". A
// live match is polled with cursors, and what arrives is appended, so scroll
// positions and the selected step stay where they are.

type Child = Node | string | undefined | false;

const h = <K extends keyof HTMLElementTagNameMap>(tag: K, attributes: Readonly<Record<string, string>> = {}, ...children: ReadonlyArray<Child>): HTMLElementTagNameMap[K] => {
  const element = document.createElement(tag);

  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value);

  for (const child of children) if (child !== undefined && child !== false) element.append(child);

  return element;
};

const svg = (tag: string, attributes: Readonly<Record<string, string>>): SVGElement => {
  const element = document.createElementNS("http://www.w3.org/2000/svg", tag);

  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value);

  return element;
};

const POLL_MS = 1_500;

/** A column scrolled to within this of its end stays pinned to its newest entry while the page follows a live match. */
const NEAR_BOTTOM_PX = 40;

const cash = (amount: number) => `$${amount.toLocaleString("en-US")}`;

const dollars = (amount: number) => `$${amount.toFixed(4)}`;

const count = (amount: number) => amount.toLocaleString("en-US");

const clock = (t: string) => t.slice(11, 23);

const day = (t: string) => new Date(t).toLocaleString("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false });

const fetchText = async (url: string): Promise<string> => {
  const response = await fetch(url);
  const text = await response.text();

  if (!response.ok) throw new Error(text);

  return text;
};

const decodeRuns = Schema.decodeUnknownSync(Schema.fromJsonString(RunsResponse));

const decodeMatch = Schema.decodeUnknownSync(Schema.fromJsonString(MatchResponse));

const statusBadge = (status: RunSummary["status"]): HTMLElement => (status === "live" ? h("span", { class: "badge-live" }, "LIVE") : h("span", { class: status === "fault" ? "status-fault" : "dim" }, status));

const standingsText = (run: RunSummary): HTMLElement =>
  h("span", {}, ...(run.standings ?? []).flatMap((standing, index) => [index > 0 && h("span", { class: "faint" }, " · "), h("span", { class: index === 0 ? "winner" : "" }, `${standing.player} ${cash(standing.cash)}`)]));

const totalsRow = (label: string, total: Total): HTMLElement =>
  h(
    "tr",
    {},
    h("td", {}, label),
    ...[total.calls, total.input, total.output, total.reasoning, total.cacheRead, total.cacheWrite].map((value) => h("td", { class: "number" }, count(value))),
    h("td", { class: "number" }, total.unpriced === total.calls ? "no price" : dollars(total.dollars)),
    h("td", { class: "number faint" }, total.unpriced > 0 && total.unpriced < total.calls ? `${total.unpriced} unpriced` : ""),
  );

const totalsTable = (title: string, rows: RunsResponse["totals"]["agents"]): HTMLElement =>
  h(
    "section",
    {},
    h("h2", {}, title),
    h(
      "table",
      {},
      h("thead", {}, h("tr", {}, ...["", "calls", "input", "output", "reasoning", "cache read", "cache write", "cost", ""].map((name) => h("th", { class: name === "" ? "" : "number" }, name)))),
      h("tbody", {}, ...rows.map(({ label, total }) => totalsRow(label, total))),
    ),
  );

const costText = ({ cost }: PricedRun): HTMLElement =>
  h("span", {}, cost.calls === 0 ? "" : cost.unpriced === cost.calls ? "no price" : dollars(cost.dollars), cost.unpriced > 0 && cost.unpriced < cost.calls && h("span", { class: "faint" }, ` +${cost.unpriced} unpriced`));

const runRow = (run: PricedRun): HTMLElement =>
  h(
    "tr",
    {},
    h("td", { class: "dim" }, day(run.started)),
    h("td", {}, h("a", { href: `/match/${encodeURIComponent(run.id)}` }, run.id)),
    h("td", {}, ...run.agents.map((agent) => h("div", {}, h("span", { class: `player-${agent.agent}` }, agent.agent), " ", h("span", { class: "dim" }, agent.model ?? "no calls yet")))),
    h("td", { class: "mono" }, ...run.seating.map((seat, index) => h("div", {}, h("span", { class: "faint" }, `${index + 1} `), seat.controller === "Agent" ? h("span", { class: `player-${seat.player}` }, seat.player) : h("span", { class: "dim" }, `${seat.player} ${seat.controller}`)))),
    h("td", { class: "mono dim" }, run.seed),
    h("td", { class: "dim" }, run.delivery),
    h("td", {}, statusBadge(run.status)),
    h("td", {}, standingsText(run)),
    h("td", { class: "mono dim" }, costText(run)),
  );

/** The list's columns, each with the sort a click on its header picks, when it has one. */
const COLUMNS: ReadonlyArray<readonly [string, SortColumn | undefined]> = [
  ["Started", "started"],
  ["Run", undefined],
  ["Agents", undefined],
  ["Seating", undefined],
  ["Seed", "seed"],
  ["Delivery", undefined],
  ["Status", "status"],
  ["Standings", "winner"],
  ["Cost", "cost"],
];

const showList = async () => {
  const { runs, totals } = decodeRuns(await fetchText("/api/runs"));
  const readable = runs.flatMap((run) => (run.kind === "readable" ? [run] : []));
  const query = new URLSearchParams(location.search);
  const choice = { model: query.get("model") ?? "", agent: query.get("agent") ?? "" };
  const models = [...new Set(readable.flatMap((run) => run.agents.flatMap((agent) => (agent.model === undefined ? [] : [agent.model]))))].toSorted();
  const letters = [...new Set(readable.flatMap((run) => run.agents.map((agent) => agent.agent)))].toSorted();
  const body = h("tbody", {});
  const head = h("thead", {});
  let order: RunOrder = orderFromQuery(query);

  const select = (name: "model" | "agent", label: string, options: ReadonlyArray<string>) => {
    const element = h("select", { "aria-label": label }, h("option", { value: "" }, label), ...options.map((option) => h("option", { value: option }, option)));

    element.value = choice[name];
    element.addEventListener("change", () => {
      choice[name] = element.value;
      render();
    });

    return element;
  };

  const isShown = (run: Run) =>
    run.kind === "unreadable" ? choice.model === "" && choice.agent === "" : run.agents.some((agent) => (choice.agent === "" || agent.agent === choice.agent) && (choice.model === "" || agent.model === choice.model));

  const headerCell = ([name, column]: (typeof COLUMNS)[number]): HTMLElement => {
    if (column === undefined) return h("th", {}, name);

    const active = order.kind === "by" && order.column === column ? order.direction : undefined;
    const button = h("button", { type: "button", class: "sort" }, name, active !== undefined && h("span", { class: "arrow" }, active === "asc" ? " ▲" : " ▼"));

    button.addEventListener("click", () => {
      order = afterClick(order, column);
      render();
    });

    return h("th", { "aria-sort": active === undefined ? "none" : active === "asc" ? "ascending" : "descending" }, button);
  };

  const render = () => {
    const next = new URLSearchParams(Object.entries(choice).filter(([, value]) => value !== ""));

    writeOrder(next, order);
    history.replaceState(null, "", next.size === 0 ? location.pathname : `?${next}`);
    head.replaceChildren(h("tr", {}, ...COLUMNS.map(headerCell)));
    body.replaceChildren(...orderRuns(runs.filter(isShown), order).map((run) => (run.kind === "readable" ? runRow(run) : h("tr", { class: "unreadable" }, h("td", {}, ""), h("td", {}, run.id), h("td", { colspan: "7" }, run.reason)))));
  };

  render();
  document.body.replaceChildren(
    h(
      "main",
      { class: "list" },
      h("h1", {}, "Arena runs"),
      h("div", { class: "filters" }, select("model", "Any model", models), select("agent", "Any agent", letters)),
      h("table", { class: "runs" }, head, body),
      h("div", { class: "totals" }, totalsTable("Per agent", totals.agents), totalsTable("Per model", totals.models)),
    ),
  );
};

const pips = (health: number, of: number): HTMLElement => h("span", { class: "pips" }, "●".repeat(health), h("span", { class: "lost" }, "●".repeat(Math.max(0, of - health))));

const boardOf = (frame: Frame): HTMLElement =>
  h(
    "div",
    { class: "board" },
    ...frame.players.map((player) =>
      h(
        "div",
        { class: `board-player${player.out ? " out" : ""}` },
        h("span", { class: `letter player-${player.player}` }, player.player),
        player.health === "jammed" ? h("span", { class: "dim" }, "jammed") : player.out ? h("span", { class: "faint" }, "out") : pips(player.health, frame.roundHealth),
        h("span", { class: "items" }, player.items.join(", ")),
        h("span", { class: "cash" }, cash(player.cash)),
      ),
    ),
    h("div", { class: "gun" }, `round ${frame.round} · ${frame.gun.live} live, ${frame.gun.blank} blank shown · ${frame.gun.remaining} left${frame.gun.sawed ? " · sawed" : ""}`),
  );

/** One line per player of health across the frames, with round starts and the selected frame marked. */
const healthStrip = (frames: ReadonlyArray<Frame>, selected: number): HTMLElement => {
  const width = Math.max(1, frames.length - 1);
  const top = Math.max(1, ...frames.map((frame) => frame.roundHealth));
  const players = frames[0]?.players.map((player) => player.player) ?? [];

  const marks = (row: SVGElement) => {
    frames.forEach((frame, index) => {
      if (index > 0 && frame.round !== frames[index - 1]?.round) row.append(svg("line", { x1: String(index), x2: String(index), y1: "0", y2: String(top), stroke: "#2c2c35", "vector-effect": "non-scaling-stroke" }));
    });
    row.append(svg("line", { x1: String(selected), x2: String(selected), y1: "0", y2: String(top), stroke: "var(--accent)", "stroke-opacity": "0.7", "vector-effect": "non-scaling-stroke" }));
  };

  return h(
    "div",
    { class: "strip" },
    ...players.map((player) => {
      let last = top;

      const points = frames.map((frame, index) => {
        const health = frame.players.find((candidate) => candidate.player === player)?.health ?? last;

        last = health === "jammed" ? last : health;

        return `${index},${top - last}`;
      });

      const row = svg("svg", { viewBox: `0 -0.5 ${width} ${top + 1}`, preserveAspectRatio: "none" });

      marks(row);
      row.append(svg("polyline", { points: points.join(" "), fill: "none", class: `player-${player}`, stroke: "currentColor", "stroke-width": "1.5", "vector-effect": "non-scaling-stroke" }));

      return h("div", { class: "strip-row" }, h("span", { class: `mono player-${player}` }, player), row);
    }),
  );
};

/** Text longer than this, or than this many lines, is cut to a few lines with a button for the rest. */
const COLLAPSE_CHARS = 180;

const COLLAPSE_LINES = 3;

/** A label over some text; with `collapse`, long text is cut to a few lines and a button shows the rest. */
const labelled = (kind: "thinking" | "text", label: string, text: string, collapse: boolean): HTMLElement => {
  const long = collapse && (text.length > COLLAPSE_CHARS || text.split("\n").length > COLLAPSE_LINES);
  const body = h("div", { class: long ? "cot-text collapsed" : "cot-text" }, text);
  const block = h("div", { class: `cot ${kind}` }, h("div", { class: "cot-label" }, label), body);

  if (long) {
    const toggle = h("button", { type: "button", class: "cot-toggle", "aria-expanded": "false" }, "more");

    toggle.addEventListener("click", (event) => {
      event.stopPropagation();

      const collapsed = body.classList.toggle("collapsed");

      toggle.textContent = collapsed ? "more" : "less";
      toggle.setAttribute("aria-expanded", String(!collapsed));
    });
    block.append(toggle);
  }

  return block;
};

const reasoningBlock = (reasoning: Reasoning, collapse: boolean): HTMLElement | undefined => {
  switch (reasoning.kind) {
    case "text":
      return labelled("thinking", reasoning.label, reasoning.text, collapse);
    case "tokens":
      return h("div", { class: "cot none" }, tokensLabel(reasoning.tokens));
    case "none":
      return undefined;
    default: {
      const _exhaustive: never = reasoning;

      return _exhaustive;
    }
  }
};

/** What a call logged of its reasoning, then the text it said aloud. */
const reasoningBlocks = (call: CallLine, collapse: boolean): ReadonlyArray<HTMLElement> => [
  reasoningBlock(reasoningOf(call), collapse),
  call.text.trim() === "" ? undefined : labelled("text", "text", call.text, collapse),
].flatMap((block) => (block === undefined ? [] : [block]));

/** The reasoning behind one move: every call its agent made for it, with a note when none logged any. */
const stepReasoning = (calls: ReadonlyArray<CallLine>): ReadonlyArray<HTMLElement> => {
  const blocks = calls.flatMap((call) => reasoningBlocks(call, true));

  return blocks.length === 0 ? [h("div", { class: "cot none" }, "no reasoning")] : blocks;
};

const stepOf = (frame: Frame, index: number): HTMLElement =>
  h(
    "div",
    { class: `step${frame.move !== undefined && frame.move.by !== "agent" ? " minor" : ""}`, "data-index": String(index) },
    h(
      "div",
      { class: "step-head" },
      h("span", { class: "turn" }, frame.move === undefined ? "" : String(frame.move.turn)),
      frame.move === undefined ? h("span", { class: "label dim" }, "start") : h("span", { class: `player-${frame.move.player}` }, frame.move.player),
      frame.move !== undefined && h("span", { class: "label" }, frame.move.label),
      frame.move !== undefined && frame.move.by !== "agent" && h("span", { class: "by" }, frame.move.by),
    ),
    frame.move !== undefined && (frame.move.by === "agent" || frame.move.by === "fallback") && h("div", { class: "reasoning" }),
    frame.entries.length > 0 && h("div", { class: "entries" }, ...frame.entries.map((entry) => (entry.heardBy === undefined ? h("div", {}, entry.text) : h("div", { class: "secret" }, entry.text, h("span", { class: "faint" }, ` heard by ${entry.heardBy}`))))),
  );

const VIA = { input: "on its turn", live: "between turns", end: "at the end" } satisfies Record<Extract<EventLine, { readonly kind: "delivered" }>["via"], string>;

const meta = (t: string, ...children: ReadonlyArray<Child>) => h("div", { class: "meta" }, h("span", { class: "time" }, clock(t)), ...children);

const callItem = ({ call, dollars: price }: PricedCall): HTMLElement =>
  h(
    "div",
    { class: "item call", "data-t": call.t },
    meta(
      call.t,
      h("span", {}, call.stop_reason),
      call.latency_ms !== undefined && h("span", {}, `${count(call.latency_ms)} ms`),
      h("span", {}, `in ${count(call.usage.input)} out ${count(call.usage.output)}${call.usage.reasoning ? ` r ${count(call.usage.reasoning)}` : ""} cache ${count(call.usage.cacheRead)}/${count(call.usage.cacheWrite)}`),
      h("span", {}, price === undefined ? "no price" : dollars(price)),
    ),
    ...reasoningBlocks(call, false),
    call.tool_calls.length > 0 && h("div", { class: "chips" }, ...call.tool_calls.map((tool) => h("span", { class: "chip" }, `${tool.name} ${JSON.stringify(tool.arguments)}`))),
    call.error !== undefined && h("div", { class: "error" }, call.error),
  );

/** An event line in its agent's column, with the turn it belongs to when it names one. */
const eventItem = (event: EventLine): HTMLElement | undefined => {
  const item = (kind: string, turn: number | undefined, ...children: ReadonlyArray<Child>) =>
    h("div", turn === undefined ? { class: `item ${kind}`, "data-t": event.t } : { class: `item ${kind}`, "data-t": event.t, "data-turn": String(turn) }, ...children);

  switch (event.kind) {
    case "seating":
      return undefined;
    case "delivered":
      return item(
        "delivered",
        event.turn,
        meta(event.t, h("span", {}, `sent ${VIA[event.via]}`), h("span", { class: "faint" }, `turn ${event.turn} · ${event.entries.length} entries`)),
        event.entries.length > 0 && h("div", { class: "entries" }, ...event.entries.map((entry) => h("div", {}, entry))),
      );
    case "tool":
      return item("tool", undefined, meta(event.t, h("span", { class: event.ok ? "chip" : "chip refused" }, `${event.name} ${event.ok ? "ok" : "refused"}`)));
    case "move":
    case "fallback":
      return item("move", event.turn, meta(event.t, h("span", {}, `turn ${event.turn}`), h("span", { class: "label" }, event.label), event.by !== "agent" && h("span", { class: "faint" }, event.by)));
    case "turn":
      return item("turn", event.turn, meta(event.t, h("span", {}, `turn ${event.turn} took ${(event.wall_ms / 1000).toFixed(1)} s`), !event.moved && h("span", { class: "error" }, "no move")));
    case "reminder":
      return item("note", event.turn, meta(event.t, `reminded to move at turn ${event.turn}`));
    case "fault":
      return item("fault", event.turn, meta(event.t, h("span", {}, `fault at turn ${event.turn}`)), h("div", {}, event.error));
    case "compaction":
      return item("note", undefined, meta(event.t, "context compacted"));
    case "resumed":
      return item("note", undefined, meta(event.t, `resumed after ${event.moves} moves`));
    case "end":
      return item("note", undefined, meta(event.t, "match over"));
    default: {
      const _exhaustive: never = event;

      return _exhaustive;
    }
  }
};

/** Places an item among those already in a column by its time, so lines from the two files interleave. */
const insertByTime = (body: HTMLElement, item: HTMLElement) => {
  const t = item.dataset["t"] ?? "";
  let after = body.lastElementChild;

  while (after instanceof HTMLElement && (after.dataset["t"] ?? "") > t) after = after.previousElementSibling;

  if (after === null) body.prepend(item);
  else after.after(item);
};

const unreadableItem = (file: string, line: JsonlLine<unknown>) => (line.kind === "unreadable" ? h("div", { class: "item unreadable" }, `${file} line ${line.line}: ${line.reason}`) : undefined);

interface Column {
  readonly sums: HTMLElement;
  readonly body: HTMLElement;
}

const showMatch = async (id: string) => {
  const url = (cursors: Cursors) => `/api/runs/${encodeURIComponent(id)}?calls=${cursors.calls}&events=${cursors.events}&frames=${cursors.frames}`;
  const first = decodeMatch(await fetchText(url({ calls: 0, events: 0, frames: 0 })));
  const frames: Array<Frame> = [];
  let selected = 0;
  const header = h("header", { class: "match-header" });
  const range = h("input", { type: "range", min: "0", max: "0", value: "0", "aria-label": "Step" });
  const position = h("span", { class: "position" });
  const boardSlot = h("div", {});
  const stripSlot = h("div", {});
  const divergence = h("div", {});
  const steps = h("div", { class: "steps" });
  const logs = h("section", { class: "logs" });
  const columns = new Map<string, Column>();
  const seen = { events: new Array<EventLine>(), calls: new Array<CallLine>() };

  const columnOf = (agent: string): Column => {
    const existing = columns.get(agent);

    if (existing !== undefined) return existing;

    const model = first.run.agents.find((candidate) => candidate.agent === agent)?.model ?? "";
    const column = { sums: h("div", { class: "sums" }), body: h("div", { class: "column-body" }) };

    logs.append(h("div", { class: "column" }, h("div", { class: "column-head" }, h("div", { class: "who" }, h("span", { class: `player-${agent}` }, `Player ${agent}`), h("span", { class: "dim" }, ` ${model}`)), column.sums), column.body));
    columns.set(agent, column);

    return column;
  };

  const select = (index: number, { scrollLogs }: { readonly scrollLogs: boolean }) => {
    const frame = frames[index];

    if (frame === undefined) return;

    selected = index;
    range.value = String(index);
    position.textContent = `${index} / ${frames.length - 1}`;
    boardSlot.replaceChildren(boardOf(frame));
    stripSlot.replaceChildren(healthStrip(frames, index));
    steps.querySelector(".selected")?.classList.remove("selected");
    steps.children[index]?.classList.add("selected");
    steps.children[index]?.scrollIntoView({ block: "nearest" });

    if (!scrollLogs) return;

    for (const { body } of columns.values()) {
      const target = frame.move === undefined ? undefined : [...body.querySelectorAll<HTMLElement>("[data-turn]")].find((item) => Number(item.dataset["turn"]) >= (frame.move?.turn ?? 0));

      body.scrollTop = target === undefined ? (frame.move === undefined ? 0 : body.scrollHeight) : target.offsetTop - 6;
    }
  };

  /** Fills each agent move's reasoning slot from the calls that led to it, as calls and moves arrive. */
  const showReasoning = () => {
    const byTurn = callsByTurn(seen.events, seen.calls);

    frames.forEach((frame, index) => {
      const slot = steps.children[index]?.querySelector<HTMLElement>(".reasoning");
      const calls = frame.move === undefined ? undefined : byTurn.get(frame.move.turn);

      if (slot === null || slot === undefined || calls === undefined || slot.dataset["calls"] === String(calls.length)) return;

      slot.dataset["calls"] = String(calls.length);
      slot.replaceChildren(...stepReasoning(calls));
    });
  };

  const apply = (update: MatchResponse) => {
    const following = selected === frames.length - 1 || frames.length === 0;
    const pinned = [...columns.values()].filter(({ body }) => frames.length === 0 || body.scrollHeight - body.scrollTop - body.clientHeight < NEAR_BOTTOM_PX);
    const { run } = update;

    header.replaceChildren(
      h("a", { class: "back", href: "/" }, "← runs"),
      h("span", { class: "name" }, run.id),
      h("span", { class: "dim mono" }, `seed ${run.seed}`),
      h("span", { class: "dim" }, `${run.delivery} delivery`),
      statusBadge(run.status),
      standingsText(run),
    );
    divergence.replaceChildren(update.divergence === undefined ? "" : h("div", { class: "divergence" }, `replay stopped: ${update.divergence}`));

    for (const line of update.calls) {
      if (line.kind === "read") {
        seen.calls.push(line.value.call);
        insertByTime(columnOf(line.value.call.agent).body, callItem(line.value));
      }
    }

    for (const line of update.events) {
      if (line.kind !== "read") continue;

      const event = line.value;

      seen.events.push(event);
      const agents = "player" in event ? [event.player] : [...columns.keys()];

      for (const agent of agents) {
        const item = eventItem(event);

        if (item !== undefined) insertByTime(columnOf(agent).body, item);
      }
    }

    for (const [file, lines] of [["calls.jsonl", update.calls], ["events.jsonl", update.events]] as const) {
      for (const line of lines) for (const { body } of columns.values()) body.append(unreadableItem(file, line) ?? "");
    }

    for (const { agent, total, latencyMs } of update.agents) {
      columnOf(agent).sums.textContent = `${total.calls} calls · in ${count(total.input)} out ${count(total.output)} r ${count(total.reasoning)} cache ${count(total.cacheRead)}/${count(total.cacheWrite)} · ${(latencyMs / 1000).toFixed(1)} s · ${total.unpriced === total.calls ? "no price" : dollars(total.dollars)}`;
    }

    steps.append(...update.frames.map((frame, offset) => stepOf(frame, frames.length + offset)));
    frames.push(...update.frames);
    showReasoning();
    range.max = String(Math.max(0, frames.length - 1));
    select(following ? frames.length - 1 : selected, { scrollLogs: false });

    if (following) for (const { body } of pinned) body.scrollTop = body.scrollHeight;

    return run.status;
  };

  range.addEventListener("input", () => select(Number(range.value), { scrollLogs: true }));
  steps.addEventListener("click", (event) => {
    const step = event.target instanceof Element ? event.target.closest<HTMLElement>(".step") : null;

    if (step !== null) select(Number(step.dataset["index"]), { scrollLogs: true });
  });
  document.addEventListener("keydown", (event) => {
    if (event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement) return;

    if (event.key === "ArrowLeft") select(Math.max(0, selected - 1), { scrollLogs: true });

    if (event.key === "ArrowRight") select(Math.min(frames.length - 1, selected + 1), { scrollLogs: true });
  });

  document.body.className = "match";
  document.body.replaceChildren(
    header,
    h(
      "main",
      { class: "match-main" },
      h(
        "section",
        { class: "timeline" },
        h("div", { class: "scrubber" }, h("button", { type: "button", "aria-label": "Previous step" }, "‹"), range, h("button", { type: "button", "aria-label": "Next step" }, "›"), position),
        boardSlot,
        stripSlot,
        divergence,
        steps,
      ),
      logs,
    ),
  );

  const [previous, next] = document.querySelectorAll<HTMLButtonElement>(".scrubber button");

  previous?.addEventListener("click", () => select(Math.max(0, selected - 1), { scrollLogs: true }));
  next?.addEventListener("click", () => select(Math.min(frames.length - 1, selected + 1), { scrollLogs: true }));

  for (const agent of first.run.agents) columnOf(agent.agent);

  let cursors = first.cursors;
  let status = apply(first);

  while (status !== "finished") {
    await new Promise((resolve) => setTimeout(resolve, POLL_MS));

    const update = decodeMatch(await fetchText(url(cursors)));

    cursors = update.cursors;
    status = apply(update);
  }

  document.body.dataset["polling"] = "stopped";
};

const route = location.pathname.match(/^\/match\/([^/]+)$/);

const shown = route?.[1] === undefined ? showList() : showMatch(decodeURIComponent(route[1]));

shown.catch((error: Error) => document.body.replaceChildren(h("main", { class: "list" }, h("h1", {}, "Could not load"), h("p", { class: "dim mono" }, error.message))));
