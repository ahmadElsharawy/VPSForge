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

  local cmd_pid
  log=$(mktemp)
  old_traps=$(trap -p INT TERM HUP)
  GUARD_INTERRUPTED=0
  GUARD_REASON=""

  # Run the command in the background and wait for it, so a Ctrl-C (or kill)
  # reaches us AT ONCE: 'wait' is interrupted by the trap even while a slow step
  # (for example an in-container apt) is still running. We then stop the command
  # and the cleanup below tears down everything the half-made operation reserved
  # (incus delete --force also kills whatever was still running inside it).
  # Output still streams live through tee.
  "$@" > >(tee "$log") 2>&1 &
  cmd_pid=$!
  trap 'GUARD_INTERRUPTED=1; kill -TERM "$cmd_pid" 2>/dev/null' INT TERM HUP
  wait "$cmd_pid"; rc=$?
  # If the signal cut the first wait short before the child was reaped, reap it now.
  wait "$cmd_pid" 2>/dev/null

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
