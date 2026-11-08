#!/usr/bin/env bash
# Installs the Rust pre-commit hook into this repository's hooks directory,
# shared by every worktree. It writes that one file and changes no git config.
# The hook runs `pre-commit` (or `prek`) from PATH on sim/rust/pre-commit-config.json,
# and does nothing in a checkout that lacks that file.
set -euo pipefail

hook=$(git rev-parse --path-format=absolute --git-path hooks)/pre-commit
if [ -e "$hook" ] && ! grep -q buckshot-rust-hook "$hook"; then
  echo "$hook exists and is not ours; remove it first" >&2
  exit 1
fi
mkdir -p "$(dirname "$hook")"
cat >"$hook" <<'HOOK'
#!/bin/sh
# buckshot-rust-hook: written by sim/rust/install-hooks.sh
config=sim/rust/pre-commit-config.json
[ -f "$config" ] || exit 0
for tool in pre-commit prek; do
  if command -v "$tool" >/dev/null; then
    exec "$tool" hook-impl --config="$config" --hook-type=pre-commit --hook-dir "$(dirname "$0")" -- "$@"
  fi
done
echo "pre-commit or prek is not on PATH (nix develop provides pre-commit)" >&2
exit 1
HOOK
chmod +x "$hook"
echo "installed $hook"
