#!/bin/bash
port_forward_auto_sync_active_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file" 2>/dev/null || true

  local tmpf
  tmpf=$(mktemp)
  touch "$tmpf"
  [ -f "$file" ] && cp "$file" "$tmpf"

  # 1. Capture any active iptables DNAT rules into the rules file if missing
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

  # 2. Also ensure each container's SSH port from metadata exists in tmpf if active/saved
  local -a inst_list=()
  mapfile -t inst_list < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  local inst inst_ip inst_port
  for inst in "${inst_list[@]}"; do
    [ -n "$inst" ] || continue
    inst_ip=$(get_ip "$inst" 2>/dev/null || true)
    inst_port=$(get_vps_saved_port "$inst" 2>/dev/null || true)
    [ -z "$inst_port" ] && inst_port=$(get_port "$inst_ip" 2>/dev/null || true)
    if [ -n "$inst_ip" ] && [ "$inst_ip" != "-" ] && [ -n "$inst_port" ] && [[ "$inst_port" =~ ^[0-9]+$ ]]; then
      local ssh_entry="tcp|0.0.0.0|${inst_port}|${inst_ip}|22"
      if ! grep -Fxq "$ssh_entry" "$tmpf" 2>/dev/null; then
        echo "$ssh_entry" >> "$tmpf"
      fi
    fi
  done

  # 3. Apply all rules from tmpf into iptables
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_apply_rule "$proto" "${ext_ip:-0.0.0.0}" "$ext_port" "$int_ip" "$int_port"
  done < "$tmpf"

  mv -f "$tmpf" "$file"
}
