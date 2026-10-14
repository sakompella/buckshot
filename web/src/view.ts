import { Array as Arr, Option } from "effect";
import type { Document, Html, HtmlBuilder } from "foldkit/html";

import type { Prompt } from "./bend.ts";
import { GameEvent, Move, type Seat, Stage } from "./domain.ts";
import { aiPrompt, controllerOf, promptsOf } from "./driver.ts";
import { latestStep, Message, type Model, SEATS_BY_TABLE, type Session, type Speed, type Viewer } from "./model.ts";
import { boardMoves, viewerPrompt } from "./board.ts";
import { hurtView, tableView } from "./board-view.ts";
import { eventText, seatName, secretText } from "./text.ts";
import { titles } from "./titles.ts";

type H = HtmlBuilder<Message>;

const cash = (amount: number): string => `$${amount.toLocaleString("en-US")}`;

// SETUP

const choice = <A>(h: H, label: string, options: ReadonlyArray<readonly [A, string]>, selected: A, toMessage: (value: A) => Message): Html =>
  h.div(
    [h.Class("choice"), h.Role("group"), h.AriaLabel(label)],
    options.map(([value, text]) => h.button([h.Type("button"), h.AriaPressed(value === selected ? "true" : "false"), h.OnClick(toMessage(value))], [text])),
  );

const setupView = (h: H, model: Model): Html => {
  const { table, controllers, isItemsEnabled, seed } = model.setup;
  const seats = SEATS_BY_TABLE[table];
  const hasAgent = seats.some((seat) => controllerOf(controllers, seat) === "Agent");

  return h.section(
    [h.Class("setup"), h.AriaLabel("Match setup")],
    [
      h.h1([h.Class("title")], ["Buckshot"]),
      h.div([h.Class("setup-row")], [h.span([h.Class("setup-label")], ["Players"]), choice(h, "Players", [[2, "2"], [3, "3"], [4, "4"]] as const, table, (value) => Message.SelectedTable({ table: value }))]),
      h.div(
        [h.Class("setup-row seats-row")],
        [
          h.span([h.Class("setup-label")], ["Seats"]),
          h.div(
            [h.Class("controllers")],
            seats.map((seat) =>
              h.button(
                [h.Type("button"), h.Class("controller"), h.AriaLabel(`${seatName(seat)}: ${controllerOf(controllers, seat)}`), h.OnClick(Message.ToggledController({ seat }))],
                [h.span([], [seatName(seat)]), h.strong([], [controllerOf(controllers, seat)])],
              ),
            ),
          ),
        ],
      ),
      hasAgent && !model.isWebMcpAvailable ? h.p([h.Class("setup-note")], ["WebMCP is not available in this browser, so no agent can play the Agent seats."]) : h.empty,
      h.div(
        [h.Class("setup-row")],
        [
          h.label([h.Class("check")], [h.input([h.Type("checkbox"), h.Checked(isItemsEnabled), h.OnChange(() => Message.ToggledItems())]), "Items"]),
          h.label([h.Class("seed-field")], ["Seed", h.input([h.Class("seed"), h.Type("number"), h.Value(String(seed)), h.OnInput((value) => Message.UpdatedSeed({ value }))])]),
        ],
      ),
      h.button([h.Type("button"), h.Class("start"), h.OnClick(Message.ClickedNewMatch())], ["Start match"]),
      Option.match(model.maybeError, { onNone: () => h.empty, onSome: (error) => h.p([h.Class("error"), h.Role("alert")], [error]) }),
    ],
  );
};

// BANNER

const isGrabbing = (prompt: Prompt): boolean => prompt.menu.some((move) => Move.guards.Grab(move) || Move.guards.Place(move));

// The hint follows the kinds of move on offer, so it never claims a move the machine does not offer.
const promptHint = (prompt: Prompt): string =>
  prompt.menu.some(Move.guards.Grab)
    ? "Open the briefcase."
    : prompt.menu.some(Move.guards.Place)
      ? "Put the item in an empty slot on your side."
      : prompt.menu.some(Move.guards.Shoot)
        ? "Choose who to shoot."
        : prompt.menu.some(Move.guards.JamTarget)
          ? "Choose who to jam."
          : prompt.menu.some(Move.guards.Steal)
            ? "Take an item from another seat."
            : "Pick up the shotgun, or use an item.";

const watchHint = (match: Session): string =>
  Stage.match(match.game.board.stage, {
    Playing: ({ seat }) => (seat === match.viewer ? "Your turn." : `${seatName(seat)}'s turn.`),
    Distributing: () => "Grabbing items.",
    Loading: () => "Loading the shotgun.",
    Setup: () => "",
    MatchOver: () => "",
  });

const viewerName = (viewer: Viewer): string => (viewer === "Spectator" ? "Spectator" : seatName(viewer));

const bannerView = (h: H, model: Model, match: Session): Html => {
  const prompt = viewerPrompt(match);
  const prompts = promptsOf(match.game);
  const otherHumans = prompts.filter((other) => other.seat !== match.viewer && controllerOf(match.controllers, other.seat) === "Human").map(({ seat }) => seat);
  const agents = prompts.filter((other) => controllerOf(match.controllers, other.seat) === "Agent").map(({ seat }) => seat);
  const isOver = match.game.pending.kind === "Finished";
  const phase = isOver ? "Match over" : Option.match(prompt, { onNone: () => "Watch", onSome: (mine) => (isGrabbing(mine) ? "Grab items" : "Your turn") });
  const hint = isOver ? "" : Option.match(prompt, { onNone: () => watchHint(match), onSome: promptHint });

  return h.header(
    [h.Class("banner"), h.AriaLive("polite")],
    [
      h.h1(
        [h.Class(Option.isSome(prompt) ? "banner-title is-mine" : "banner-title")],
        Option.match(roundJustWon(match), {
          onNone: () => [`${viewerName(match.viewer)} · ${phase}`],
          // The phase waits behind "Round over" until the round-over beat ends.
          onSome: ({ index }) => [
            `${viewerName(match.viewer)} · `,
            h.keyed("span")(`phase-${index}`, [h.Class("phase")], [h.span([h.Class("phase-beat")], ["Round over"]), h.span([h.Class("phase-after")], [phase])]),
          ],
        }),
      ),
      hint === "" ? h.empty : h.p([h.Class("hint")], [hint]),
      ...agents.map((seat) => h.p([h.Class("hint")], [`Waiting for the agent at ${seatName(seat)}.`])),
      ...otherHumans.map((seat) => h.button([h.Type("button"), h.Class("pass"), h.OnClick(Message.SelectedViewer({ viewer: seat }))], [`Take ${seatName(seat)}`])),
      Option.match(model.maybeError, { onNone: () => h.empty, onSome: (error) => h.p([h.Class("error"), h.Role("alert")], [error]) }),
    ],
  );
};

// Moves that no single thing on the table stands for.
const looseMovesView = (h: H, match: Session): Html =>
  Option.match(viewerPrompt(match), {
    onNone: () => h.empty,
    onSome: (prompt) => {
      const { buttons } = boardMoves(prompt);

      return buttons.length === 0
        ? h.empty
        : h.div(
            [h.Class("loose-moves")],
            buttons.map(({ index, label }) =>
              h.button([h.Type("button"), h.OnClick(Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index }))], [label]),
            ),
          );
    },
  });

const NOTES_SHOWN = 3;

const notesView = (h: H, match: Session): Html => {
  const mine = match.learned.filter(({ seat }) => seat === match.viewer).slice(-NOTES_SHOWN);

  return mine.length === 0
    ? h.empty
    : h.aside(
        [h.Class("notes"), h.AriaLabel(`Private notes for ${viewerName(match.viewer)}`)],
        [h.ul([], mine.map(({ secret }, index) => h.keyed("li")(`${match.learned.length}-${index}`, [], [secretText(secret)])))],
      );
};

/** The round the latest step ended, if any: the table and the heading show it for one beat. */
const roundJustWon = (match: Session): Option.Option<{ readonly index: number; readonly seat: Seat; readonly prize: number }> =>
  match.game.pending.kind === "Finished"
    ? Option.none()
    : Arr.head(latestStep(match).flatMap(({ index, event }) => (GameEvent.guards.RoundWon(event) ? [{ index, seat: event.seat, prize: event.prize }] : [])));

/** Keyed by the round, so its CSS animation plays once. */
const roundOverView = (h: H, match: Session): Html =>
  Option.match(roundJustWon(match), {
    onNone: () => h.empty,
    onSome: ({ index, seat, prize }) =>
      h.keyed("div")(
        `round-${index}`,
        [h.Class("round-over"), h.AriaHidden(true)],
        [h.p([h.Class("round-over-title")], ["Round over"]), h.p([h.Class("round-over-prize")], [`${seatName(seat)} takes ${cash(prize)}`])],
      ),
  });

const resultsView = (h: H, match: Session): Html => {
  const standings = match.game.board.seats.toSorted((left, right) => right.cash - left.cash);

  return h.section(
    [h.Class("results"), h.AriaLabel("Results")],
    [
      h.ol([h.Class("standings")], standings.map((view) => h.li([], [h.span([], [seatName(view.seat)]), h.strong([], [cash(view.cash)])]))),
      h.dl(
        [h.Class("titles")],
        titles(match.events, match.game.seats).flatMap((title) => [
          h.dt([], [title.name]),
          h.dd([], [title.seats.length === 0 ? `Nobody (${title.description})` : `${title.seats.map(seatName).join(", ")}: ${title.score} ${title.description}`]),
        ]),
      ),
      h.div(
        [h.Class("results-actions")],
        [h.button([h.Type("button"), h.OnClick(Message.ClickedNewMatch())], ["Play again"]), h.button([h.Type("button"), h.OnClick(Message.ClickedLeaveMatch())], ["Change seats"])],
      ),
    ],
  );
};

// MENU

const SPEEDS: ReadonlyArray<readonly [Speed, string]> = [
  ["Slow", "Slow"],
  ["Normal", "Normal"],
  ["Fast", "Fast"],
];

const LOG_SHOWN = 60;

const menuView = (h: H, model: Model, match: Session): Html => {
  const hasBotMove = Option.isSome(aiPrompt(match.game, match.controllers));
  const hasAgent = match.game.seats.some((seat) => controllerOf(match.controllers, seat) === "Agent");

  return h.details(
    [h.Class("menu")],
    [
      h.summary([], ["Menu"]),
      h.div(
        [h.Class("menu-body")],
        [
          h.div(
            [h.Class("menu-row")],
            [
              h.button([h.Type("button"), h.AriaPressed(match.isAutoplay ? "true" : "false"), h.OnClick(Message.ToggledAutoplay())], [match.isAutoplay ? "Pause bots" : "Run bots"]),
              h.button([h.Type("button"), h.Class("step"), h.Disabled(!hasBotMove), h.OnClick(Message.ClickedStep())], ["Step"]),
              h.button([h.Type("button"), h.OnClick(Message.ClickedLeaveMatch())], ["Leave"]),
            ],
          ),
          h.div([h.Class("menu-row")], [h.span([], ["Speed"]), choice(h, "Speed", SPEEDS, model.speed, (speed) => Message.SelectedSpeed({ speed }))]),
          h.div(
            [h.Class("menu-row")],
            [
              h.span([], ["View"]),
              choice<Viewer>(h, "View as", [["Spectator", "All"], ...match.game.seats.map((seat): readonly [Viewer, string] => [seat, `${seat}`])], match.viewer, (viewer) => Message.SelectedViewer({ viewer })),
            ],
          ),
          h.p([h.Class("menu-seats")], [match.game.seats.map((seat: Seat) => `${seatName(seat)} ${controllerOf(match.controllers, seat)}`).join(", ")]),
          hasAgent ? h.p([h.Class("menu-seats")], [model.isWebMcpAvailable ? "WebMCP tools are registered." : "WebMCP is not available in this browser."]) : h.empty,
          h.ol(
            [h.Class("log"), h.AriaLabel("Event log")],
            match.events
              .slice(-LOG_SHOWN)
              .map((event, offset) => h.keyed("li")(match.events.length - LOG_SHOWN + offset, [], [eventText(event)]))
              .toReversed(),
          ),
        ],
      ),
    ],
  );
};

const matchView = (h: H, model: Model, match: Session): Html => {
  const isOver = match.game.pending.kind === "Finished";

  return h.div(
    [h.Class("game")],
    [
      bannerView(h, model, match),
      tableView(h, match, model.matchCount),
      hurtView(h, match, model.matchCount),
      match.game.pending.kind === "Stuck" ? h.p([h.Class("error")], ["The machine is stuck: no seat has a legal move."]) : h.empty,
      looseMovesView(h, match),
      notesView(h, match),
      roundOverView(h, match),
      isOver ? resultsView(h, match) : h.empty,
      menuView(h, model, match),
    ],
  );
};

export const view = (model: Model, h: H): Document => ({
  title: "Buckshot table",
  body: h.main(
    [h.Class("app")],
    [Option.match(model.maybeMatch, { onNone: () => setupView(h, model), onSome: (match) => matchView(h, model, match) })],
  ),
});
