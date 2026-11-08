#!/bin/bash
port_forward_disable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file."; return; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"

  touch "${file}.disabled"   # remembered, so listing the rules does not switch them on again
  save_iptables
  echo "Port forward rules disabled (kept in file)."
}
