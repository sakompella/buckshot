import "./site/styles.css";
import { Runtime } from "foldkit";

import { init, Model, Message, onUrlChange, onUrlRequest, subscriptions, update, view } from "./site/main.ts";

const application = Runtime.makeApplication({
  Model,
  init,
  update,
  view,
  subscriptions,
  routing: { onUrlChange, onUrlRequest },
  container: document.getElementById("root"),
  devTools: { Message },
});

Runtime.run(application);
