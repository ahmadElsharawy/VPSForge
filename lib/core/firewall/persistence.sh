#!/bin/bash
# VPSForge v1.0.0 — Port forward rules file persistence.

port_forward_append_rule_to_file() {
  local file="$1" proto="$2" ext_ip="$3" ext_port="$4" int_ip="$5" int_port="$6"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  echo "${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}" >> "$file"
}

port_forward_remove_rule_from_file() {
  local file="$1" proto="$2" ext_ip="$3" ext_port="$4" int_ip="$5" int_port="$6"
  [ -f "$file" ] || return 0
  local pattern="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
  local tmpf
  tmpf=$(mktemp)
  grep -vFx "$pattern" "$file" > "$tmpf" 2>/dev/null || true
  mv -f "$tmpf" "$file"
}

port_forward_auto_sync_active_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  > "$file"

  iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | while read -r rule; do
    local proto ext_ip ext_port int_ip int_port dest_flag

    proto=$(echo "$rule" | sed -n 's/.*-p \([a-z]*\).*/\1/p')
    [ -n "$proto" ] || continue

    ext_port=$(echo "$rule" | sed -n 's/.*--dport \([0-9]*\).*/\1/p')
    [ -n "$ext_port" ] || continue

    if echo "$rule" | grep -q '\-d '; then
      ext_ip=$(echo "$rule" | sed -n 's/.*-d \([0-9.]*\).*/\1/p')
    else
      ext_ip="0.0.0.0"
    fi

    local dest
    dest=$(echo "$rule" | sed -n 's/.*--to-destination \([^ ]*\).*/\1/p')
    int_ip="${dest%%:*}"
    int_port="${dest##*:}"

    [ -n "$int_ip" ] && [ -n "$int_port" ] || continue

    echo "${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}" >> "$file"
  done
}
