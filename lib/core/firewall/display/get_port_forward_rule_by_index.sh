#!/bin/bash
# Retrieve a port forward rule line from the rules file by 1-based line index.
get_port_forward_rule_by_index() {
  local index="$1" file="${2:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || return 1
  awk -F'|' -v idx="$index" '$1 != "" { n++; if (n == idx) { print; exit } }' "$file"
}
