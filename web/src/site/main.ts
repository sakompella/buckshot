import { Effect, Option, Schema } from "effect";
import { Command, Navigation, Submodel, Subscription, Update, type Url } from "foldkit";
import type { Document, Html, HtmlBuilder } from "foldkit/html";
import { defineMessageUnion } from "foldkit/message";
import { modifyFields } from "foldkit/struct";

import * as Arena from "../arena-viewer/page/main.ts";
import { Message as ArenaMessage, Model as ArenaModel } from "../arena-viewer/page/model.ts";
import { view as arenaView } from "../arena-viewer/page/view.ts";
import arenaStyles from "../arena-viewer/page/styles.css?inline";
import { type ArenaRoute, isArenaRoute, isRootUrl, routeOf, SiteRoute } from "./route.ts";

// The site: the arena's analysis under Arena, asking the arena server for its data.

export const Model = Schema.Struct({
  route: SiteRoute,
  maybeArena: Schema.Option(ArenaModel),
});

export type Model = typeof Model.Type;

export const Message = defineMessageUnion({
  ChangedUrl: { route: SiteRoute, href: Schema.String },
  RequestedUrl: { request: Navigation.UrlRequest },
  CompletedNavigation: {},
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

const toArenaMessage = (message: ArenaMessage): Message => Message.GotArenaMessage({ message });

const writeArena = (model: Model, arena: ArenaModel): Model => modifyFields(model, { maybeArena: () => Option.some(arena) });

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

/** Writes what the arena now shows into the URL, so a link shares it and a reload keeps it. */
const withArenaUrl = (before: Option.Option<ArenaModel>, after: Return): Return =>
  Option.match(Option.all([before, after.model.maybeArena]), {
    onNone: () => after,
    onSome: ([was, arena]) => {
      const href = Arena.hrefOf(arena);

      if (!isArenaRoute(after.model.route) || href === Arena.hrefOf(was)) return after;

      return { model: after.model, commands: [...(after.commands ?? []), ReplaceUrl(href + location.hash)] };
    },
  });

const changedUrl = (model: Model, route: SiteRoute, href: string): Return => {
  const routed = modifyFields(model, { route: () => route });
  const isArenaShowing = Option.exists(model.maybeArena, (arena) => Arena.hrefOf(arena) === href);

  if (!isArenaRoute(route) || isArenaShowing) return { model: routed };

  return enterArena(routed, route);
};

export const update = (model: Model, message: Message): Return =>
  Message.match<Return>(message, {
    ChangedUrl: ({ route, href }) => changedUrl(model, route, href),
    RequestedUrl: ({ request }) =>
      Navigation.UrlRequest.match(request, {
        Internal: ({ url }) => ({ model, commands: [PushUrl(hrefOfUrl(url))] }),
        External: ({ href }) => ({ model, commands: [LoadUrl(href)] }),
      }),
    CompletedNavigation: () => ({ model }),
    GotArenaMessage: ({ message: arenaMessage }) => withArenaUrl(model.maybeArena, foldArena(model, arenaMessage)),
  });

export const init = (url: Url.Url): Return => {
  const route = routeOf(url);
  const start: Model = { route, maybeArena: Option.none() };
  const arena = isArenaRoute(route) ? enterArena(start, route) : { model: start };
  // The root is the arena: it moves to the arena's own URL, keeping a section link such as `/#scatter`.
  const moved = isRootUrl(url) ? [ReplaceUrl(`/arena${location.hash}`)] : [];

  return { model: arena.model, commands: [...(arena.commands ?? []), ...moved] };
};

export const onUrlChange = (url: Url.Url): Message => Message.ChangedUrl({ route: routeOf(url), href: hrefOfUrl(url) });

export const onUrlRequest = (request: Navigation.UrlRequest): Message => Message.RequestedUrl({ request });

const isArenaShown = (model: Model): boolean => isArenaRoute(model.route);

export const subscriptions = Subscription.lift(Arena.subscriptions)<Model, Message>({
  read: (model) => model.maybeArena,
  toParentMessage: toArenaMessage,
  when: { scroll: isArenaShown, tappedTitle: isArenaShown, tourKeys: isArenaShown, hash: isArenaShown },
});

type H = HtmlBuilder<Message>;

const arenaBody = Submodel.defineView<ArenaModel, ArenaMessage>((model, h) => arenaView(model, h).body);

const navView = (h: H, model: Model): Html => {
  const link = (label: string, href: string, isCurrent: boolean) => h.a([h.Href(href), ...(isCurrent ? [h.AriaCurrent("page")] : [])], [label]);

  return h.nav(
    [h.Class("site-nav"), h.AriaLabel("Site"), h.Inert(Option.exists(model.maybeArena, (arena) => Option.isSome(arena.maybeTour)))],
    [
      h.span([h.Class("site-name")], ["Buckshot"]),
      link("Arena", Option.match(model.maybeArena, { onNone: () => "/arena", onSome: (arena) => Arena.hrefOf(arena) }), isArenaRoute(model.route)),
    ],
  );
};

const ARENA_STYLES = arenaStyles;

const pageOf = (h: H, model: Model, page: Html): Html => h.div([h.Class("site")], [h.style([], [ARENA_STYLES]), navView(h, model), page]);

export const view = (model: Model, h: H): Document =>
  SiteRoute.match(model.route, {
    Arena: () => arenaPage(h, model),
    NotFound: ({ path }) => ({
      title: "Buckshot",
      body: pageOf(h, model, h.main([], [h.p([h.Class("k")], [`Nothing lives at ${path}. `, h.a([h.Href("/arena")], ["The arena"]), " has every config's results."])])),
    }),
  });

const arenaPage = (h: H, model: Model): Document => ({
  title: "Buckshot Arena",
  body: pageOf(
    h,
    model,
    Option.match(model.maybeArena, {
      onNone: () => h.empty,
      onSome: (arena) => h.submodel({ slotId: "arena", view: arenaBody, model: arena, toParentMessage: toArenaMessage }),
    }),
  ),
});
