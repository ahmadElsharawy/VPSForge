#!/bin/bash
port_forward_delete_rules_for_ip() {
  local target_ip="$1" file="${2:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || return 0

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    if [ "$int_ip" = "$target_ip" ]; then
      port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
    fi
  done < "$file"

  local tmpf
  tmpf=$(mktemp)
  awk -F'|' -v ip="$target_ip" '$4 != ip' "$file" > "$tmpf" 2>/dev/null || true
  mv -f "$tmpf" "$file"
  save_iptables
}
