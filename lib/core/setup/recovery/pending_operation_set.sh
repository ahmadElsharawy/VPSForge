#!/bin/bash
# Record, BEFORE the VPS exists, that this process is creating/importing/cloning <name> with <ip>/<port>.
# If the process dies (kill -9, power cut) even before Incus has finished making the instance,
# startup recovery still knows what to clean up. Cleared when the operation ends.
#   pending_operation_set <name> <ip> <port>
pending_operation_set() {
  local name="${1:?name}" ip="${2:-}" port="${3:-}" start
  start=$(sed 's/^.*) //' "/proc/$$/stat" 2>/dev/null | awk '{print $20}')
  mkdir -p "$PENDING_DIR" 2>/dev/null || return 0
  printf '%s:%s|%s|%s\n' "$$" "$start" "$ip" "$port" > "$PENDING_DIR/$name"
}
