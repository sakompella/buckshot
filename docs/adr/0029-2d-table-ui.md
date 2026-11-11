---
status: superseded
---

# 2D table UI

> Superseded 2026-11-10 by ADR-0053: the table UI, its fonts and its art are deleted with the game table. The text below is kept as history.

The page plays on a top-down table drawn in DOM, CSS and SVG. It replaces the plain panel UI. The table holds the information: health is the bolts on each defibrillator, a load is its shells laid out in a live group and a blank group, a shot is the gun turning with its flash and recoil, and a private result shows in the middle for a moment, only to its player. Each legal move is a button on the thing it acts on, so Tab and Enter play it too, and `src/board.ts` maps moves to things and falls back to plain buttons for any two moves that would share one. After each step autoplay waits as long as its animation, scaled by the speed setting, at any table. Either way ADR-0001 holds: the view asks the machine and never decides a rule. Fonts are League Gothic and VT323 from `@fontsource`, under the SIL Open Font License, and all art is our own (ADR-0028).

## Considered Options

- The plain panel UI: it works, but reads as a form rather than a table.
- The whole table as a three.js scene: it has the room, the light and the camera of the original, at the cost of a WebGL context, a heavier bundle, and a scene whose timings and hit targets are harder to check headlessly. The user chose the 2D table.
