import "./site/styles.css";
import { Runtime } from "foldkit";

import { fetchLayer } from "./arena-viewer/page/main.ts";
import { init, Model, Message, onUrlChange, onUrlRequest, subscriptions, update, view } from "./site/main.ts";

const application = Runtime.makeApplication({
  Model,
  init,
  update,
  view,
  subscriptions,
  routing: { onUrlChange, onUrlRequest },
  resources: fetchLayer,
  container: document.getElementById("root"),
  devTools: { Message },
});

Runtime.run(application);
