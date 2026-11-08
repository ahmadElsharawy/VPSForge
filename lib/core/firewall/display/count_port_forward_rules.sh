#!/bin/bash
count_port_forward_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo 0; return; }
  grep -cE '^[a-z]+\|' "$file" 2>/dev/null || echo 0
}
