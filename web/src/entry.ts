import { Runtime } from "foldkit";

import { init, Message, Model, subscriptions, update, view } from "./main.ts";

const application = Runtime.makeApplication({
  Model,
  init,
  update,
  view,
  subscriptions,
  container: document.getElementById("root"),
  // Bend's JS reads its arguments in place, so the Model must stay unfrozen.
  freezeModel: false,
  // Each update runs the Bend machine (tens of ms on a long match).
  slow: { thresholdOverrides: { Update: 150, Patch: 32 } },
  devTools: { Message },
});

Runtime.run(application);
