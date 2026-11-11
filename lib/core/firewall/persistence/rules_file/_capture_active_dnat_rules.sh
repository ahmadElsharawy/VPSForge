#!/bin/bash
# Capture active iptables DNAT rules for VPS containers into a destination file.
_capture_active_dnat_rules() {
  local target_file="$1"
  local rule proto ext_ip ext_port dest int_ip int_port entry

  iptables -t nat -S PREROUTING 2>/dev/null | grep -E '\-j DNAT' | while read -r rule; do
    proto=$(echo "$rule" | sed -n 's/.*-p \([a-z0-9]*\).*/\1/p')
    [ -n "$proto" ] || continue

    ext_port=$(echo "$rule" | sed -n 's/.*--dport \([0-9]*\).*/\1/p')
    [ -n "$ext_port" ] || continue

    if echo "$rule" | grep -q '\-d '; then
      ext_ip=$(echo "$rule" | sed -n 's/.*-d \([0-9.]*\).*/\1/p')
    else
      ext_ip="0.0.0.0"
    fi

    dest=$(echo "$rule" | sed -n 's/.*--to-destination \([^ ]*\).*/\1/p')
    int_ip="${dest%%:*}"
    int_port="${dest##*:}"

    [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    # Only forwards into the VPS network are ours; the owner's other DNAT rules are left alone.
    [[ "$int_ip" == "${NETWORK_PREFIX:-@none@}."* ]] || continue

    entry="${proto}|${ext_ip}|${ext_port}|${int_ip}|${int_port}"
    if ! grep -Fxq "$entry" "$target_file" 2>/dev/null; then
      echo "$entry" >> "$target_file"
    fi
  done
}
