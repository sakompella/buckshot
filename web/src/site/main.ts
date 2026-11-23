import { Effect, Option, Schema } from "effect";
import { Command, Navigation, Submodel, Subscription, Update } from "foldkit";
import type { Url } from "foldkit";
import type { Document, Html, HtmlBuilder } from "foldkit/html";
import { defineMessageUnion } from "foldkit/message";
import { modifyFields } from "foldkit/struct";

import * as Arena from "../arena-viewer/page/main.ts";
import { Message as ArenaMessage, Model as ArenaModel } from "../arena-viewer/page/model.ts";
import { view as arenaView } from "../arena-viewer/page/view.ts";
import { isArenaRoute, isRootUrl, routeOf, SiteRoute } from "./route.ts";
import type { ArenaRoute } from "./route.ts";

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

type Return = Update.Return<Model, Message, Arena.Resources>;

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
const arenaUrlCommands = (before: Option.Option<ArenaModel>, after: Model) =>
  Option.match(Option.all([before, after.maybeArena]), {
    onNone: () => [],
    onSome: ([was, arena]) => {
      const href = Arena.hrefOf(arena);

      return !isArenaRoute(after.route) || href === Arena.hrefOf(was) ? [] : [ReplaceUrl(href + location.hash)];
    },
  });

const changedUrl = (model: Model, route: SiteRoute, href: string): Return => {
  const routed = modifyFields(model, { route: () => route });
  const isArenaShowing = Option.exists(model.maybeArena, (arena) => Arena.hrefOf(arena) === href);

  if (!isArenaRoute(route) || isArenaShowing) { return { model: routed }; }

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
    GotArenaMessage: ({ message: arenaMessage }) => {
      const { model: next, commands = [] } = foldArena(model, arenaMessage);

      return { model: next, commands: [...commands, ...arenaUrlCommands(model.maybeArena, next)] };
    },
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

const pageOf = (h: H, page: Html): Html => h.div([h.Class("site")], [page]);

export const view = (model: Model, h: H): Document =>
  SiteRoute.match(model.route, {
    Arena: () => arenaPage(h, model),
    NotFound: ({ path }) => ({
      title: "Not found · Buckshot Arena",
      body: pageOf(h, h.main([], [h.p([h.Class("k")], [`There is no page at ${path}. `, h.a([h.Href("/arena")], ["The arena"]), " has every config's results."])])),
    }),
  });

const arenaPage = (h: H, model: Model): Document => ({
  title: "Buckshot Arena: language models playing Buckshot Roulette",
  body: pageOf(
    h,
    Option.match(model.maybeArena, {
      onNone: () => h.empty,
      onSome: (arena) => h.submodel({ slotId: "arena", view: arenaBody, model: arena, toParentMessage: toArenaMessage }),
    }),
  ),
});
