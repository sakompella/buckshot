import "./styles.css";

// Tooltips for the figures' marks: each `[data-tip]` mark shows its text on mouse hover, keyboard focus or a tap, a tap
// docking it as a bottom sheet. Esc or a tap elsewhere hides it. A cost-chart mark also lights its family's line.

const tip = document.body.appendChild(Object.assign(document.createElement("div"), { className: "tip", role: "tooltip", hidden: true }));

let lastPointer = "mouse";

const markOf = (target: EventTarget | null): Element | null => (target instanceof Element ? target.closest("[data-tip]") : null);

const light = (mark: Element | null): void => {
  for (const lit of document.querySelectorAll(".lit, .focusing")) { lit.classList.remove("lit", "focusing"); }

  const family = mark?.getAttribute("data-family") ?? null;
  const chart = mark?.closest("svg") ?? null;

  if (family === null || chart === null) { return; }

  chart.classList.add("focusing");

  for (const member of chart.querySelectorAll(`[data-family="${family}"]`)) { member.classList.add("lit"); }
};

const hide = (): void => {
  tip.hidden = true;
  light(null);
};

const place = (x: number, y: number): void => {
  const width = tip.offsetWidth;
  const height = tip.offsetHeight;
  const left = Math.min(Math.max(8, x + 14), window.innerWidth - width - 8);
  const top = y + 18 + height > window.innerHeight ? y - height - 12 : y + 18;

  tip.style.left = `${left}px`;
  tip.style.top = `${Math.max(8, top)}px`;
};

const show = (mark: Element, x: number, y: number): void => {
  const docked = lastPointer === "touch";

  tip.textContent = mark.getAttribute("data-tip");
  tip.classList.toggle("docked", docked);
  tip.hidden = false;
  light(mark);

  if (docked) {
    tip.style.left = "";
    tip.style.top = "";
  } else { place(x, y); }
};

const showAt = (mark: Element): void => {
  const box = mark.getBoundingClientRect();

  show(mark, box.left + box.width / 2 - 14, box.top + box.height / 2);
};

document.addEventListener("pointerdown", (event) => {
  lastPointer = event.pointerType;

  if (markOf(event.target) === null && !(event.target instanceof Node && tip.contains(event.target))) { hide(); }
});

document.addEventListener("pointerover", (event) => {
  const mark = markOf(event.target);

  if (event.pointerType !== "touch" && mark !== null) {
    lastPointer = event.pointerType;
    show(mark, event.clientX, event.clientY);
  }
});

document.addEventListener("pointermove", (event) => {
  if (event.pointerType !== "touch" && !tip.hidden && markOf(event.target) !== null) { place(event.clientX, event.clientY); }
});

document.addEventListener("pointerout", (event) => {
  if (event.pointerType !== "touch" && markOf(event.relatedTarget) === null) { hide(); }
});

document.addEventListener("click", (event) => {
  const mark = markOf(event.target);

  if (mark !== null && lastPointer === "touch") { showAt(mark); }
});

document.addEventListener("focusin", (event) => {
  const mark = markOf(event.target);

  if (mark !== null) { showAt(mark); }
});

document.addEventListener("focusout", (event) => {
  if (markOf(event.relatedTarget) === null && lastPointer !== "touch") { hide(); }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") { hide(); }
});
