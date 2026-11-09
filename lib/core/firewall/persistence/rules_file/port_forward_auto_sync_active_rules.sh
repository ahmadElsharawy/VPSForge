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
    # Only forwards into the VPS network are ours; the owner's other DNAT rules are left alone.
    [[ "$int_ip" == "${NETWORK_PREFIX:-@none@}."* ]] || continue

    local entry="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
    if ! grep -Fxq "$entry" "$tmpf" 2>/dev/null; then
      echo "$entry" >> "$tmpf"
    fi
  done

  # 2. Also ensure each container's SSH port from metadata exists in tmpf if active/saved
  local inst inst_ip inst_port
  while IFS='|' read -r inst inst_ip inst_port; do
    [ -n "$inst" ] || continue
    [ -z "$inst_port" ] && inst_port=$(get_port "$inst_ip" 2>/dev/null || true)
    if [ -n "$inst_ip" ] && [ "$inst_ip" != "-" ] && [[ "$inst_port" =~ ^[0-9]+$ ]]; then
      local ssh_entry="tcp|0.0.0.0|${inst_port}|${inst_ip}|22"
      if ! grep -Fxq "$ssh_entry" "$tmpf" 2>/dev/null; then
        echo "$ssh_entry" >> "$tmpf"
      fi
    fi
  done < <(vps_inventory)

  # 3. Apply all rules from tmpf into iptables (not while the owner has them disabled)
  [ -f "${file}.disabled" ] || while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_apply_rule "$proto" "${ext_ip:-0.0.0.0}" "$ext_port" "$int_ip" "$int_port"
  done < "$tmpf"

  mv -f "$tmpf" "$file"
}
