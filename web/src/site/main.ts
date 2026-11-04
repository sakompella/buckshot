import { Effect, Option, Predicate, Schema } from "effect";
import { Command, Navigation, Submodel, Subscription, Update, type Url } from "foldkit";
import type { Document, Html, HtmlBuilder } from "foldkit/html";
import { defineMessageUnion } from "foldkit/message";
import { modifyFields } from "foldkit/struct";

import * as Arena from "../arena-viewer/page/main.ts";
import { Message as ArenaMessage, Model as ArenaModel } from "../arena-viewer/page/model.ts";
import { view as arenaView } from "../arena-viewer/page/view.ts";
import arenaStyles from "../arena-viewer/page/styles.css?inline";
import * as Play from "../main.ts";
import { Message as PlayMessage, Model as PlayModel } from "../model.ts";
import playStyles from "../styles.css?inline";
import tableStyles from "../table.css?inline";
import { view as playView } from "../view.ts";
import { type ArenaRoute, isArenaRoute, isOldArenaLink, PLAY_HREF, routeOf, SiteRoute } from "./route.ts";

// The site: the game under Play, the arena's analysis under Arena, and one arena match under Replay. Play needs
// nothing but the page; Arena and Replay ask the arena server for its data, and only once one of them is opened.

export const Model = Schema.Struct({
  route: SiteRoute,
  play: PlayModel,
  maybeArena: Schema.Option(ArenaModel),
  /** Whether the open replay's history entry is one this page pushed, so closing the replay goes back to the arena. */
  isReplayPushed: Schema.Boolean,
});

export type Model = typeof Model.Type;

export const Message = defineMessageUnion({
  ChangedUrl: { route: SiteRoute, href: Schema.String },
  RequestedUrl: { request: Navigation.UrlRequest },
  CompletedNavigation: {},
  GotPlayMessage: { message: PlayMessage },
  GotArenaMessage: { message: ArenaMessage },
});

export type Message = typeof Message.Type;

type Return = Update.Return<Model, Message>;

const hrefOfUrl = (url: Url.Url): string => url.pathname + Option.match(url.search, { onNone: () => "", onSome: (search) => `?${search}` });

const navigation = (name: string, effect: Effect.Effect<void>) =>
  Command.define(name, { messages: [Message.CompletedNavigation], execute: effect.pipe(Effect.as(Message.CompletedNavigation())) });

const PushUrl = (href: string) => navigation("PushUrl", Navigation.pushUrl(href))();
const ReplaceUrl = (href: string) => navigation("ReplaceUrl", Navigation.replaceUrl(href))();
const LoadUrl = (href: string) => navigation("LoadUrl", Navigation.load(href))();
const GoBack = () => navigation("GoBack", Navigation.back())();

const toPlayMessage = (message: PlayMessage): Message => Message.GotPlayMessage({ message });
const toArenaMessage = (message: ArenaMessage): Message => Message.GotArenaMessage({ message });

const writeArena = (model: Model, arena: ArenaModel): Model => modifyFields(model, { maybeArena: () => Option.some(arena) });

const foldPlay = Update.foldChild({
  update: Play.update,
  read: (model: Model) => Option.some(model.play),
  write: (model: Model, play: PlayModel) => modifyFields(model, { play: () => play }),
  toParentMessage: toPlayMessage,
});

const foldArena = Update.foldChild({ update: Arena.update, read: (model: Model) => model.maybeArena, write: writeArena, toParentMessage: toArenaMessage });

const enterArena = (model: Model, route: ArenaRoute): Return =>
  Option.match(model.maybeArena, {
    onNone: () => {
      const { model: arena, commands } = Arena.init(Arena.viewportNow(), route);

      return { model: writeArena(model, arena), commands: Command.mapMessages(commands, toArenaMessage) };
    },
    onSome: (arena) => {
      const { model: next, commands } = Arena.withRoute(arena, route);

      return { model: writeArena(model, next), commands: Command.mapMessages(commands, toArenaMessage) };
    },
  });

/** Writes what the arena now shows into the URL: opening a replay adds a history entry, closing it leaves that entry. */
const withArenaUrl = (before: Option.Option<ArenaModel>, after: Return): Return =>
  Option.match(Option.all([before, after.model.maybeArena]), {
    onNone: () => after,
    onSome: ([was, arena]) => {
      const href = Arena.hrefOf(arena);

      if (!isArenaRoute(after.model.route) || href === Arena.hrefOf(was)) return after;

      const isOpening = Option.isNone(was.maybeReplay) && Option.isSome(arena.maybeReplay);
      const isClosing = Option.isSome(was.maybeReplay) && Option.isNone(arena.maybeReplay);

      const [command, isReplayPushed] = isOpening
        ? [PushUrl(href), true]
        : isClosing && after.model.isReplayPushed
          ? [GoBack(), false]
          : [ReplaceUrl(Option.isSome(arena.maybeReplay) ? href : href + location.hash), after.model.isReplayPushed && !isClosing];

      return { model: modifyFields(after.model, { isReplayPushed: () => isReplayPushed }), commands: [...(after.commands ?? []), command] };
    },
  });

const changedUrl = (model: Model, route: SiteRoute, href: string): Return => {
  const routed = modifyFields(model, { route: () => route });
  const isArenaShowing = Option.exists(model.maybeArena, (arena) => Arena.hrefOf(arena) === href);

  if (!isArenaRoute(route) || isArenaShowing) return { model: routed };

  return enterArena(modifyFields(routed, { isReplayPushed: () => false }), route);
};

export const update = (model: Model, message: Message): Return =>
  Message.match<Return>(message, {
    ChangedUrl: ({ route, href }) => changedUrl(model, route, href),
    RequestedUrl: ({ request }) =>
      Navigation.UrlRequest.match(request, {
        // The database download is the server's, not a page of the site.
        Internal: ({ url }) => ({ model, commands: [url.pathname.startsWith("/api/") ? LoadUrl(hrefOfUrl(url)) : PushUrl(hrefOfUrl(url))] }),
        External: ({ href }) => ({ model, commands: [LoadUrl(href)] }),
      }),
    CompletedNavigation: () => ({ model }),
    GotPlayMessage: ({ message: playMessage }) => foldPlay(model, playMessage),
    GotArenaMessage: ({ message: arenaMessage }) => withArenaUrl(model.maybeArena, foldArena(model, arenaMessage)),
  });

export const init = (flags: Play.Flags, url: Url.Url): Return => {
  const play = Play.init(flags);
  const route = routeOf(url);
  const start: Model = { route, play: play.model, maybeArena: Option.none(), isReplayPushed: false };
  const arena = isArenaRoute(route) ? enterArena(start, route) : { model: start };
  // An old link to an arena section (`/#scatter`) moves to the arena's own URL, keeping the section.
  const moved = isOldArenaLink(url) ? [ReplaceUrl(`/arena${location.hash}`)] : [];

  return { model: arena.model, commands: [...Command.mapMessages(play.commands, toPlayMessage), ...(arena.commands ?? []), ...moved] };
};

export const onUrlChange = (url: Url.Url): Message => Message.ChangedUrl({ route: routeOf(url), href: hrefOfUrl(url) });

export const onUrlRequest = (request: Navigation.UrlRequest): Message => Message.RequestedUrl({ request });

const isArenaShown = (model: Model): boolean => isArenaRoute(model.route);

export const subscriptions = Subscription.aggregate(
  Subscription.lift(Play.subscriptions)<Model, Message>({ read: (model) => Option.some(model.play), toParentMessage: toPlayMessage }),
  Subscription.lift(Arena.subscriptions)<Model, Message>({
    read: (model) => model.maybeArena,
    toParentMessage: toArenaMessage,
    when: { replayKeys: isArenaShown, scroll: isArenaShown, tappedTitle: isArenaShown, tourKeys: isArenaShown, hash: isArenaShown },
  }),
);

type H = HtmlBuilder<Message>;

const playBody = Submodel.defineView<PlayModel, PlayMessage>((model, h) => playView(model, h).body);

const arenaBody = Submodel.defineView<ArenaModel, ArenaMessage>((model, h) => arenaView(model, h).body);

const navView = (h: H, model: Model): Html => {
  const link = (label: string, href: string, isCurrent: boolean) => h.a([h.Href(href), ...(isCurrent ? [h.AriaCurrent("page")] : [])], [label]);

  return h.nav(
    [h.Class("site-nav"), h.AriaLabel("Site")],
    [
      h.span([h.Class("site-name")], ["Buckshot"]),
      link("Play", PLAY_HREF, Predicate.isTagged(model.route, "Play")),
      link("Arena", Option.match(model.maybeArena, { onNone: () => "/arena", onSome: (arena) => Arena.hrefOf(arena) }), isArenaRoute(model.route)),
    ],
  );
};

// Each page brings its own stylesheet, and only the shown page's applies: the two set the same root variables and elements.
// Both draw the table, so both bring its stylesheet first.
const PLAY_STYLES = `${tableStyles}\n${playStyles}`;

const ARENA_STYLES = `${tableStyles}\n${arenaStyles}`;

const pageOf = (h: H, model: Model, styles: string, page: Html): Html =>
  h.div([h.Class(`site ${Predicate.isTagged(model.route, "Play") ? "site-play" : "site-arena"}`)], [h.style([], [styles]), navView(h, model), page]);

export const view = (model: Model, h: H): Document =>
  SiteRoute.match(model.route, {
    Play: () => ({ title: "Buckshot table", body: pageOf(h, model, PLAY_STYLES, h.submodel({ slotId: "play", view: playBody, model: model.play, toParentMessage: toPlayMessage })) }),
    Arena: () => arenaPage(h, model),
    Replay: () => arenaPage(h, model),
    NotFound: ({ path }) => ({
      title: "Buckshot",
      body: pageOf(h, model, ARENA_STYLES, h.main([], [h.p([h.Class("k")], [`Nothing lives at ${path}. `, h.a([h.Href("/arena")], ["The arena"]), " has every config's results."])])),
    }),
  });

const arenaPage = (h: H, model: Model): Document => ({
  title: "Buckshot Arena",
  body: pageOf(
    h,
    model,
    ARENA_STYLES,
    Option.match(model.maybeArena, {
      onNone: () => h.empty,
      onSome: (arena) => h.submodel({ slotId: "arena", view: arenaBody, model: arena, toParentMessage: toArenaMessage }),
    }),
  ),
});
