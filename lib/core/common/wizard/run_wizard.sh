#!/bin/bash
# Run a multi-step wizard where typing 0 goes back ONE step (not to the start).
# Each step is a function that asks one question and returns:
#   0  = answered, go to the next step
#   10 = user typed 0 (Back): previous step; on the first step this leaves the wizard
#   anything else = cancel the whole wizard with that code
# Returns 0 when every step was answered, 1 when the user backed out of step 1.
#   run_wizard step_function_1 step_function_2 ...
run_wizard() {
  local -a steps=("$@")
  local i=0 rc
  while [ "$i" -lt "${#steps[@]}" ]; do
    "${steps[$i]}"
    rc=$?
    case "$rc" in
      0)  i=$((i + 1));;
      "$WIZARD_BACK")
          [ "$i" -eq 0 ] && return 1
          i=$((i - 1));;
      *)  return "$rc";;
    esac
  done
  return 0
}
