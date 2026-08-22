#!/bin/bash
# VPSForge v1.0.0 — Port forward display and status.

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
}

get_port_forward_rule_by_index() {
  local index="$1" file="${2:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || return 1
  sed -n "${index}p" "$file"
}

count_port_forward_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  [ -f "$file" ] || { echo 0; return; }
  grep -cE '^[a-z]+\|' "$file" 2>/dev/null || echo 0
}

port_forward_status() {
  echo "=== Active NAT PREROUTING Rules ==="
  iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null || true
  echo
  echo "=== Active FORWARD Rules ==="
  iptables -L FORWARD -n --line-numbers 2>/dev/null | head -n 60 || true
  echo
  local file="${PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    echo "=== Saved Port Forward File ($file) ==="
    cat "$file"
  else
    echo "=== No saved port forward file ==="
  fi
}
