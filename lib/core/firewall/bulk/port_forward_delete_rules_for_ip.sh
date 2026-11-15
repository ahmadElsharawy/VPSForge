#!/bin/bash
# Delete all port forward rules targeting a specific VPS internal IP.
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
  # replace the file only if awk really wrote the new list (a full disk must not empty every forward)
  if awk -F'|' -v ip="$target_ip" '$4 != ip' "$file" > "$tmpf" 2>/dev/null; then
    mv -f "$tmpf" "$file"
  else
    rm -f "$tmpf"
  fi
  save_iptables
}
