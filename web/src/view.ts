import { Array as Arr, Option } from "effect";
import type { Document, Html, HtmlBuilder } from "foldkit/html";

import type { Prompt } from "./bend.ts";
import { GameEvent, Move, type Seat, SEATS_BY_TABLE, seatsOut } from "./domain.ts";
import { aiPrompt, controllerOf, promptsOf } from "./driver.ts";
import { latestLearned, latestStep, Message, type Model, type Session, type Speed, SPEED_FACTOR, type Viewer } from "./model.ts";
import { rosterOf } from "./players.ts";
import { boardMoves, nearSeat, promptMoves, type TableMove, viewerPrompt } from "./board.ts";
import { hurtView, type SeatTable, tableView } from "./board-view.ts";
import { eventText, secretShout, secretText } from "./text.ts";
import { titles } from "./titles.ts";

type H = HtmlBuilder<Message>;

const cash = (amount: number): string => `$${amount.toLocaleString("en-US")}`;

/** The round-over beat and the load reveal, as long as their CSS animations. */
const ROUND_OVER_MS = 4400;

const REVEAL_MS = 2600;

// SETUP

const choice = <A>(h: H, label: string, options: ReadonlyArray<readonly [A, string]>, selected: A, toMessage: (value: A) => Message): Html =>
  h.div(
    [h.Class("choice"), h.Role("group"), h.AriaLabel(label)],
    options.map(([value, text]) => h.button([h.Type("button"), h.AriaPressed(value === selected ? "true" : "false"), h.OnClick(toMessage(value))], [text])),
  );

const setupView = (h: H, model: Model): Html => {
  const { table, controllers, isItemsEnabled, seed } = model.setup;
  const seats = SEATS_BY_TABLE[table];
  const roster = rosterOf(seats);
  const hasAgent = seats.some((seat) => controllerOf(controllers, seat) === "Agent");

  return h.section(
    [h.Class("setup"), h.AriaLabel("Match setup")],
    [
      h.h1([h.Class("title")], ["Buckshot"]),
      h.div([h.Class("setup-row")], [h.span([h.Class("setup-label")], ["Players"]), choice(h, "Players", [[2, "2"], [3, "3"], [4, "4"]] as const, table, (value) => Message.SelectedTable({ table: value }))]),
      h.div(
        [h.Class("setup-row seats-row")],
        [
          h.span([h.Class("setup-label")], ["Controllers"]),
          h.div(
            [h.Class("controllers")],
            seats.map((seat) =>
              h.button(
                [h.Type("button"), h.Class("controller"), h.AriaLabel(`${roster.nameOf(seat)}: ${controllerOf(controllers, seat)}`), h.OnClick(Message.ToggledController({ seat }))],
                [h.span([], [roster.nameOf(seat)]), h.strong([], [controllerOf(controllers, seat)])],
              ),
            ),
          ),
        ],
      ),
      hasAgent && !model.isWebMcpAvailable ? h.p([h.Class("setup-note")], ["WebMCP is not available in this browser, so Agent players cannot move."]) : h.empty,
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

/** Shown while aiming until the viewer has shot themselves once this match: the one move the table does not make obvious. */
const selfShotCue = (match: Session, prompt: Prompt): boolean =>
  prompt.menu.some((move) => Move.guards.Shoot(move) && move.target === prompt.seat) &&
  !match.events.some((event) => GameEvent.guards.Fired(event) && event.shooter === prompt.seat && event.target === prompt.seat);

const nameIn = (match: Session, seat: Seat): string => rosterOf(match.game.seats).nameOf(seat);

const viewerName = (match: Session): string => (match.viewer === "Spectator" ? "Spectator" : nameIn(match, match.viewer));

const bannerView = (h: H, model: Model, match: Session): Html => {
  const prompt = viewerPrompt(match);
  const prompts = promptsOf(match.game);
  const otherHumans = prompts.filter((other) => other.seat !== match.viewer && controllerOf(match.controllers, other.seat) === "Human").map(({ seat }) => seat);
  const agents = prompts.filter((other) => controllerOf(match.controllers, other.seat) === "Agent").map(({ seat }) => seat);
  const isOver = match.game.pending.kind === "Finished";
  const phase = isOver ? "Match over" : Option.match(prompt, { onNone: () => "Watch", onSome: (mine) => (isGrabbing(mine) ? "Grab items" : "Your turn") });
  const isCued = Option.exists(prompt, (mine) => selfShotCue(match, mine));

  return h.header(
    [h.Class("banner"), h.AriaLive("polite")],
    [
      h.h1(
        [h.Class(Option.isSome(prompt) ? "banner-title is-mine" : "banner-title")],
        Option.match(roundJustWon(match), {
          onNone: () => [`${viewerName(match)} · ${phase}`],
          // The phase waits behind "Round over" until the round-over beat ends.
          onSome: ({ index }) => [
            `${viewerName(match)} · `,
            h.keyed("span")(`phase-${index}`, [h.Class("phase")], [h.span([h.Class("phase-beat")], ["Round over"]), h.span([h.Class("phase-after")], [phase])]),
          ],
        }),
      ),
      isCued ? h.p([h.Class("hint")], ["To shoot yourself, click your own defibrillator."]) : h.empty,
      ...agents.map((seat) => h.p([h.Class("hint")], [`Waiting for the agent at ${nameIn(match, seat)}.`])),
      ...otherHumans.map((seat) => h.button([h.Type("button"), h.Class("pass"), h.OnClick(Message.SelectedViewer({ viewer: seat }))], [`Take ${nameIn(match, seat)}`])),
      Option.match(model.maybeError, { onNone: () => h.empty, onSome: (error) => h.p([h.Class("error"), h.Role("alert")], [error]) }),
    ],
  );
};

/** The viewer's legal moves, and the message that plays each through the machine. */
const viewerMoves = (match: Session): { readonly moves: ReadonlyArray<TableMove>; readonly onMove: Option.Option<(index: number) => Message> } =>
  Option.match(viewerPrompt(match), {
    onNone: () => ({ moves: [], onMove: Option.none() }),
    onSome: (prompt) => ({
      moves: promptMoves(rosterOf(match.game.seats), prompt),
      onMove: Option.some((index: number) => Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index })),
    }),
  });

const seatTableOf = (match: Session, matchNumber: number): SeatTable => ({
  board: match.game.board,
  near: nearSeat(match),
  out: seatsOut(match.events),
  shells: Option.none(),
  recent: latestStep(match),
  key: `${matchNumber}`,
});

// Moves that no single thing on the table stands for.
const looseMovesView = (h: H, match: Session): Html => {
  const { moves, onMove } = viewerMoves(match);
  const { buttons } = boardMoves(moves);

  return Option.match(onMove, {
    onNone: () => h.empty,
    onSome: (toMessage) =>
      buttons.length === 0 ? h.empty : h.div([h.Class("loose-moves")], buttons.map(({ index, label }) => h.button([h.Type("button"), h.OnClick(toMessage(index))], [label]))),
  });
};

/**
 * The latest secret the viewer learned, big in the middle of the screen for a
 * moment. It waits for a round-over or a load reveal in the same step, so the
 * two never cover each other.
 */
const secretView = (h: H, match: Session): Html =>
  Option.match(
    Arr.findLast(latestLearned(match), ({ learned }) => learned.seat === match.viewer),
    {
      onNone: () => h.empty,
      onSome: ({ index, learned }) => {
        const step = latestStep(match).map(({ event }) => event);
        const waitMs = (step.some(GameEvent.guards.RoundWon) ? ROUND_OVER_MS : 0) + (step.some(GameEvent.guards.Loaded) ? REVEAL_MS : 0);

        return h.keyed("p")(
          `secret-${index}`,
          [h.Class("secret"), h.Role("status"), h.AriaLabel(secretText(learned.secret)), h.Style({ "--wait": `${waitMs}ms` })],
          [secretShout(learned.secret)],
        );
      },
    },
  );

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
        [h.p([h.Class("round-over-title")], ["Round over"]), h.p([h.Class("round-over-prize")], [`${nameIn(match, seat)} takes ${cash(prize)}`])],
      ),
  });

const resultsView = (h: H, match: Session): Html => {
  const standings = match.game.board.seats.toSorted((left, right) => right.cash - left.cash);

  return h.section(
    [h.Class("results"), h.AriaLabel("Results")],
    [
      h.ol([h.Class("standings")], standings.map((view) => h.li([], [h.span([], [nameIn(match, view.seat)]), h.strong([], [cash(view.cash)])]))),
      h.div(
        [h.Class("results-actions")],
        [h.button([h.Type("button"), h.OnClick(Message.ClickedNewMatch())], ["Play again"]), h.button([h.Type("button"), h.OnClick(Message.ClickedLeaveMatch())], ["Change players"])],
      ),
      h.details(
        [h.Class("awards")],
        [
          h.summary([], ["Awards"]),
          h.dl(
            [h.Class("titles")],
            titles(match.events, match.game.seats).flatMap((title) => [
              h.dt([], [title.name]),
              h.dd([], [title.seats.length === 0 ? `Nobody (${title.description})` : `${title.seats.map((seat) => nameIn(match, seat)).join(", ")}: ${title.score} ${title.description}`]),
            ]),
          ),
        ],
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
          h.p([h.Class("menu-seats")], [match.game.seats.map((seat: Seat) => `${nameIn(match, seat)} ${controllerOf(match.controllers, seat)}`).join(", ")]),
          hasAgent ? h.p([h.Class("menu-seats")], [model.isWebMcpAvailable ? "WebMCP tools are registered." : "WebMCP is not available in this browser."]) : h.empty,
          h.ol(
            [h.Class("log"), h.AriaLabel("Event log")],
            match.events
              .slice(-LOG_SHOWN)
              .map((event, offset) => h.keyed("li")(match.events.length - LOG_SHOWN + offset, [], [eventText(rosterOf(match.game.seats), event)]))
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
      tableView(h, { view: seatTableOf(match, model.matchCount), ...viewerMoves(match), chosen: Option.none() }),
      match.viewer === "Spectator" ? h.empty : hurtView(h, seatTableOf(match, model.matchCount)),
      match.game.pending.kind === "Stuck" ? h.p([h.Class("error")], ["The machine is stuck: no seat has a legal move."]) : h.empty,
      looseMovesView(h, match),
      secretView(h, match),
      roundOverView(h, match),
      isOver ? resultsView(h, match) : h.empty,
      menuView(h, model, match),
    ],
  );
};

export const view = (model: Model, h: H): Document => ({
  title: "Buckshot table",
  body: h.main(
    [h.Class("app"), h.Style({ "--pace": `${SPEED_FACTOR[model.speed]}` })],
    [Option.match(model.maybeMatch, { onNone: () => setupView(h, model), onSome: (match) => matchView(h, model, match) })],
  ),
});
