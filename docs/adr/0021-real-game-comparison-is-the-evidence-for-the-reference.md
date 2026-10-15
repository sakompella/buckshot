# Comparison with the real game is the evidence for the reference

The laws prove the machine equals the reference. Nothing proves the reference equals the real game, so that link is testing. A local harness loads a copy of the real multiplayer scene headless, with only Steam stubbed, and sends moves as the packets a client sends, through the host's real verification. It replays random configs and random answer tapes through the real game and the reference, and compares the trace at every request point. A small mechanical edit of the copy reads draws and moves from the tape. The same edit carries M1, M3 and M4 (ADR-0016). Results are recorded in `sim/bend-mp/README.md`.

## Consequences

The harness needs the decompiled game, so it is not in git (ADR-0028) and a reader cannot rerun it without their own copy. Its limits are stated in the README. Menus come from a function over host fields, not from client code, and a request point is a one-second quiet period that was checked by comparing traces, not proven.
