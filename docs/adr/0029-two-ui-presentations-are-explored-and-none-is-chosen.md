---
status: proposed
---

# Two UI presentations are explored and none is chosen

The plain panel UI on `main` works and is the default. Two branches try a different look over the same machine and agent tools. `web/game-look` plays on a top-down table with the shotgun as a 3D object. `web/game-3d` draws the whole table as a three.js scene that is played by clicking things in it. No winner is picked yet. One cost is already visible. With a scene on screen, bots at a table with agents keep Fast pace, so that agents do not wait for the animation. Whichever presentation wins, ADR-0001 holds: it asks the machine and never decides a rule.
