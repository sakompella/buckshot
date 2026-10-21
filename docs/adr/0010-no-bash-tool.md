---
status: accepted
---

# No bash tool

An optional per-player bash tool over just-bash, a TypeScript shell with a virtual filesystem, was asked for. It is deferred until the basic arena has produced results. The agentfs-sdk 0.6.4 adapter, which would back that filesystem with SQLite, fails on just-bash 3.6.0 at the first command because its filesystem lacks `realpath`. It would also be a second store whose writes are not committed with pi-durable's, so a crash in the middle of a command could leave files that the transcript does not explain. When the tool is built, the plan is just-bash's in-memory filesystem, saved in the player's pi-durable conversation in the same commit as each command's result. Files start empty and do not carry over between matches: rotations share a seed, so notes from one rotation would reveal the next one's shells.
