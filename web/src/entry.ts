import "@fontsource/league-gothic/400.css";
import "@fontsource/vt323/400.css";
import "./site/styles.css";
import { Effect } from "effect";
import { Runtime } from "foldkit";

import { init, Model, Message, onUrlChange, onUrlRequest, subscriptions, update, view } from "./site/main.ts";
import { Flags } from "./main.ts";
import { ports, registerAgentTools } from "./webmcp.ts";

const application = Runtime.makeApplication({
  Model,
  Flags,
  init,
  update,
  view,
  subscriptions,
  ports,
  routing: { onUrlChange, onUrlRequest },
  container: document.getElementById("root"),
  // Bend's JS reads its arguments in place, so the Model must stay unfrozen.
  freezeModel: false,
  // Each update runs the Bend machine (tens of ms on a long match).
  slow: { thresholdOverrides: { Update: 150, Patch: 32 } },
  devTools: { Message },
});

const modelContext = document.modelContext;

// The runtime is embedded, not run, so the tools can talk to it through its ports.
const { ports: handles } = Runtime.embed(application, { flags: Effect.succeed({ isWebMcpAvailable: modelContext !== undefined }) });

if (modelContext !== undefined) registerAgentTools(modelContext, handles).catch((error: Error) => console.error("WebMCP registration failed", error));
