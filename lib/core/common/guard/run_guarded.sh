#!/bin/bash
# Run a long operation so that NOTHING is left behind if it stops half-way.
#   run_guarded "<cleanup command>" <command> [args...]
# The command's output is shown live. If the command fails OR is stopped
# (Ctrl-C, terminal closed, kill), the cleanup command runs with the reason as
# its last argument, and a clear message says what happened. Returns the
# command's exit code (130 when interrupted).
run_guarded() {
  local cleanup="${1:?cleanup command}"; shift
  local log rc old_traps reason

  log=$(mktemp)
  old_traps=$(trap -p INT TERM HUP)
  GUARD_INTERRUPTED=0
  GUARD_REASON=""
  # Survive the signal in this shell: the running command still gets it and stops.
  trap 'GUARD_INTERRUPTED=1' INT TERM HUP

  "$@" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}

  trap - INT TERM HUP
  [ -n "$old_traps" ] && eval "$old_traps"

  if [ "$GUARD_INTERRUPTED" -eq 1 ]; then
    rc=130
    reason="it was stopped before it finished (Ctrl-C, closed terminal or kill)"
  elif [ "$rc" -ne 0 ]; then
    reason=$(grep -E '^(ERROR|Error|FAILED|Failed)' "$log" | tail -n 1 | sed -E 's/^(ERROR|Error|FAILED|Failed):? *//')
    [ -n "$reason" ] || reason="the last step failed (exit code $rc)"
  fi
  rm -f "$log"

  if [ "$rc" -ne 0 ]; then
    GUARD_REASON="$reason"
    echo
    echo "!! The operation did not finish: $reason."
    echo "!! Cleaning up everything it had reserved..."
    eval "$cleanup \"\$reason\""
    echo "!! Clean. Nothing was left behind."
  fi
  return "$rc"
}
