# Provenance

Vendored copy of `src/` from https://github.com/dmmulroy/anti-slop
at commit 13909c9e07590f5a85d93c62712259fe14a883f7 (MIT, see LICENSE).
Copied unmodified on 2026-10-22 (previously c44ef22); still upstream's latest commit on 2026-11-18
(every file byte-identical). Upstream pins oxlint and @oxlint/plugins 1.78.0; this app runs both
at 1.94.0 (one exact shared version).

The rule tests are not part of `bun run test` (Oxlint's RuleTester refuses Bun). Run them
with Node 22 or later from `web/`: `bun run test:lint-rules`.
