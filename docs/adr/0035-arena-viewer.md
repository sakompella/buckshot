# Arena viewer

`bun run viewer` serves a site for browsing arena matches from their run directories. It is a separate tool, not part of the web app, which stays a static page with no server (ADR-0027). The viewer's server reads `manifest.json`, `events.jsonl` and `calls.jsonl`, and never writes them or opens `session.sqlite`. It binds 127.0.0.1 only and has no auth, so anything wider, such as a tailnet, goes through a proxy in front of it. It replays the match through the rules machine from the seed and the logged moves (ADR-0001), and prices calls with the arena's own cost code (ADR-0008). Its page polls with cursors, the counts of lines it already has, so the server keeps no state for a page and a live match is followed as its logs grow.

## Considered Options

- Reading the run directories from the static page: a browser cannot list or tail local files, and the replay needs the run files on disk.
- Server-sent events with a tail per connection: they need per-connection state and reconnect handling, and cursors give the same result with plain requests.
- Viewing the pi-durable store directly: it is the arena's record and is open while a match runs (ADR-0006). The JSONL logs already say what the viewer shows.
