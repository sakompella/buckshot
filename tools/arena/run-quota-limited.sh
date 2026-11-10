#!/bin/sh
# Plays a tournament under a Claude quota line, for launchd so it outlives agent sessions:
#   launchctl submit -l LABEL -o "$TD/runner.log" -e "$TD/runner.log" -- /usr/bin/env TD=... CONFIG=... WEB=... LABEL=... /bin/sh tools/arena/run-quota-limited.sh
# Environment:
#   TD      tournament directory (holds .mgmt, the CPA management password, mode 600)
#   CONFIG  tournament config      WEB  web/ directory of the checkout whose code new matches start under
#   LABEL   the launchd label, removed when the run stops for good
#   SOFT=0.78 HARD=0.80  Claude lines: the least-used Claude account must be below SOFT to start and HARD while playing
#   PARALLEL=2           matches at once
#   CAP                  play only the first CAP matches of the schedule (the runner's --first; default: all)
#   CODE                 extra runner flags, such as "--code <code_sha>=<web dir>" for matches started on older code
# Codex is not checked here: pinned matches pause per account in the runner (ADR-0042).
# It stops for good, with no resume after resets, on the Claude line or when the first CAP matches are finished
# (exit 0), or on a runner failure, a fallback move or failed audit (check_matches.py, also run after the runner
# exits and before a finished run ends) (exit 1).
export PATH=/usr/local/bin:/etc/profiles/per-user/aditya/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin
TOOLS=$(cd "$(dirname "$0")" && pwd)
SOFT=${SOFT:-0.78}
HARD=${HARD:-0.80}
PARALLEL=${PARALLEL:-2}
cd "$WEB" || exit 1
note() { printf '%s\n' "- $(date '+%Y-%m-%d %-I:%M %p') $*" >> "$TD/PROGRESS.md"; echo "run: $*"; }
guard() { python3 "$TOOLS/quota_guard.py" "$1" --mgmt-file "$TD/.mgmt" --claude-only; }
left() { python3 -c "import json,os,sys; s=json.load(open('$TD/tournament.json'))['schedule']; s=s[:int(sys.argv[1])] if sys.argv[1] else s; print(sum(not (os.path.exists(p) and json.load(open(p)).get('status')=='finished') for p in (os.path.join('$TD',m['name'],'manifest.json') for m in s)))" "${CAP:-}"; }
check() { python3 "$TOOLS/check_matches.py" "$TD" > /dev/null 2>&1; }
BAD="a fallback move, failed audit or unexpected endpoint"
# finish STATUS REASON: 0 for a cap or quota stop, 1 for a fault.
finish() { note "stopped: $2"; guard "$SOFT" >> "$TD/PROGRESS.md" 2>&1; launchctl remove "$LABEL"; exit "$1"; }
while :; do
  if [ -f "$TD/tournament.json" ] && [ "$(left)" -eq 0 ]; then
    check || finish 1 "$BAD"
    finish 0 "all scheduled matches played"
  fi
  guard "$SOFT" > /dev/null 2>&1 || finish 0 "Claude at or over $SOFT on its least-used account (or quota unknown)"
  note "runner starts"
  # shellcheck disable=SC2086
  ( exec nice -n 10 bun scripts/arena-tournament.ts "$CONFIG" --dir "$TD" --parallel "$PARALLEL" ${CAP:+--first "$CAP"} ${CODE:-} ) &
  pid=$!
  stop=""
  while kill -0 "$pid" 2>/dev/null; do
    sleep 30
    guard "$HARD" > /dev/null 2>&1 || { kill -TERM "$pid"; stop="Claude at or over $HARD during play"; code=0; }
    check || { kill -TERM "$pid"; stop="$BAD"; code=1; }
  done
  wait "$pid"; status=$?
  [ -n "$stop" ] && finish "$code" "$stop (runner $pid stopped; its matches resume from journals)"
  check || finish 1 "$BAD"
  [ "$(left)" -eq 0 ] && continue
  finish 1 "runner exited $status with matches left (see runner.log)"
done
