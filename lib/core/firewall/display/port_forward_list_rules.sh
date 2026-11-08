#!/bin/bash
port_forward_list_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}" idx=0
  port_forward_auto_sync_active_rules "$file"
  [ -f "$file" ] || { echo "(No port forward rules configured.)"; return; }

  printf "%-5s %-6s %-16s %-10s %-16s %-10s %-12s\n" \
    "#" PROTO EXT_IP EXT_PORT INT_IP INT_PORT VPS_NAME
  printf '%s\n' "-----------------------------------------------------------------------------"

  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] || continue
    idx=$((idx + 1))
    local vps_name
    vps_name=$(get_vps_name_by_ip "$int_ip" 2>/dev/null || echo "-")
    printf "%-5s %-6s %-16s %-10s %-16s %-10s %-12s\n" \
      "$idx" "$proto" "${ext_ip:-any}" "$ext_port" "$int_ip" "$int_port" "$vps_name"
  done < "$file"

  [ "$idx" -eq 0 ] && echo "(No port forward rules configured.)"
  return 0
}
