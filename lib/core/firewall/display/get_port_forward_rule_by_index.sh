#!/bin/bash
get_port_forward_rule_by_index() {
  local index="$1" file="${2:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || return 1
  sed -n "${index}p" "$file"
}
