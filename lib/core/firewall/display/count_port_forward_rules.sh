#!/bin/bash
# Return the total number of configured port forwarding rules.
count_port_forward_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo 0; return 0; }
  grep -cE '^[a-z]+\|' "$file" 2>/dev/null || true
}
