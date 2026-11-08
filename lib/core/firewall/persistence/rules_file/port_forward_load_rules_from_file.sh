#!/bin/bash
port_forward_load_rules_from_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo "No rules file found at $file."; return 1; }

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$file"
  save_iptables
  echo "Rules loaded from $file."
}
