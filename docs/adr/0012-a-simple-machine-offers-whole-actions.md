---
status: proposed
---

# A simple machine offers whole actions

A third model is in progress on branch `bend/simple-sm`. It reuses the machine's world, players and rule functions, but its only choices are whole actions such as "Shoot Player B" or "Steal beer from Player B", not one step at a time. A bridge plays each simple answer as a chain of machine steps, so the strong machine stays the authority. If it lands, the whole-action moves of ADR-0002 would come from the rules library instead of from a search in TypeScript (ADR-0001). It is checked against the machine by a smoke gate and a fuzz test so far, with no laws yet. Nothing here is merged or decided: whether it replaces the search is open.
