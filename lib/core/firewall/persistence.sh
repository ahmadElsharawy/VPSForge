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
  touch "$file" 2>/dev/null || true

  local tmpf
  tmpf=$(mktemp)
  touch "$tmpf"
  [ -f "$file" ] && cp "$file" "$tmpf"

  iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | while read -r rule; do
    local proto ext_ip ext_port int_ip int_port

    proto=$(echo "$rule" | sed -n 's/.*-p \([a-z0-9]*\).*/\1/p')
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

    local entry="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
    if ! grep -Fxq "$entry" "$tmpf" 2>/dev/null; then
      echo "$entry" >> "$tmpf"
    fi
  done

  # Verify and retain only rules that actually exist in iptables
  local verified_tmpf
  verified_tmpf=$(mktemp)
  touch "$verified_tmpf"
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    if iptables -t nat -S PREROUTING 2>/dev/null | grep -qE -- "-p $proto .*--dport $ext_port .*--to-destination $int_ip:$int_port"; then
      echo "${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}" >> "$verified_tmpf"
    fi
  done < "$tmpf"
  rm -f "$tmpf"
  mv -f "$verified_tmpf" "$file"
}
