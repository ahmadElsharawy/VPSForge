#!/bin/bash
# Turns a CPU cap percent and core count into a hard Incus allowance ("140ms/100ms" = 70% of 2 cores).
# Sets CPU_ALLOWANCE_VALUE; empty for 100% (no cap). A plain "70%" in Incus is only a soft share.
cpu_cap_to_allowance() {
  local pct="$1" cores="${2:-1}"
  CPU_ALLOWANCE_VALUE=""
  [ "$pct" -ge 100 ] && return 0
  CPU_ALLOWANCE_VALUE="$((pct * cores))ms/100ms"
}
