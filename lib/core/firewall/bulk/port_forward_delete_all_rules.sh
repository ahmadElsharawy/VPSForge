#!/bin/bash
port_forward_delete_all_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file found."; return; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"

  > "$file"
  save_iptables
  echo "All port forward rules deleted."
}
