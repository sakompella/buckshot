import { Config, Effect, Option, type Scope } from "effect";
import { type Browser, chromium, firefox } from "playwright-core";

import { ScriptError } from "../src/script.ts";

// The headless browser play.ts and shots.ts drive: Chrome, at $CHROME, or with BROWSER=firefox Playwright's Firefox (at $FIREFOX if it is not the installed revision).

const settings = Config.all({
  chrome: Config.withDefault(Config.String("CHROME"), "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
  browser: Config.withDefault(Config.String("BROWSER"), "chromium"),
  firefox: Config.option(Config.String("FIREFOX")),
});

/** A launched browser, closed when its scope ends, however the script ends. */
export const launchBrowser: Effect.Effect<Browser, ScriptError | Config.ConfigError, Scope.Scope> = Effect.gen(function* () {
  const { chrome, browser, firefox: firefoxPath } = yield* settings;

  return yield* Effect.acquireRelease(
    Effect.tryPromise({
      try: () => (browser === "firefox" ? firefox.launch({ executablePath: Option.getOrElse(firefoxPath, () => firefox.executablePath()), headless: true }) : chromium.launch({ executablePath: chrome, headless: true })),
      catch: (cause) => new ScriptError({ message: `could not launch the browser: ${String(cause)}`, exitCode: 1 }),
    }),
    (launched) => Effect.promise(() => launched.close()),
  );
});
