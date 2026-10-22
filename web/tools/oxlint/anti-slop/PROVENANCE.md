# Provenance

Vendored copy of `src/` from https://github.com/dmmulroy/anti-slop
at commit 13909c9e07590f5a85d93c62712259fe14a883f7 (MIT, see LICENSE).
Copied unmodified on 2026-10-22 (previously c44ef22). Upstream pins oxlint and @oxlint/plugins
1.78.0; this app runs both at 1.87.0 (one exact shared version).

The rule tests are not part of `bun run test`. Oxlint's RuleTester refuses Bun,
so run each with Node 22 or later from `web/`:
`node --experimental-strip-types tools/oxlint/anti-slop/rules/<rule>.test.ts`
(and `effect/rules/` likewise).
