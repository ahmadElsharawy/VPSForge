#!/bin/bash
restore_vps_port_forwards_metadata() {
  local name="$1" ip rules proto ext_ip ext_port int_port rule
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  # 1. Try to restore from the container's own metadata rules (enables restoration on new servers or if IP changed!)
  rules=$(incus config get "$name" user.vpsforge.port_forwards.rules 2>/dev/null || true)
  if [ -n "$rules" ]; then
    mkdir -p "$(dirname "$PORT_FORWARD_RULES_FILE")"
    touch "$PORT_FORWARD_RULES_FILE"
    IFS=';' read -ra rule_arr <<< "$rules"
    for rule in "${rule_arr[@]}"; do
      [ -n "$rule" ] || continue
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
      # Skip empty values
      [ -n "$proto" ] && [ -n "$ext_port" ] || continue
      is_valid_port_forward_rule "$proto" "$ext_ip" "$ext_port" "$int_port" || continue
      
      # Apply custom rule with the container's current IP
      port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
      
      # Also add it to our rules file if not already present
      if ! grep -Fxq "${proto}|${ext_ip}|${ext_port}|${ip}|${int_port}" "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
        echo "${proto}|${ext_ip}|${ext_port}|${ip}|${int_port}" >> "$PORT_FORWARD_RULES_FILE"
      fi
    done
    save_iptables
    return 0
  fi

  # 2. Fallback to the original host-rules-file lookup
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 0
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ "$int_ip" = "$ip" ] || continue
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$PORT_FORWARD_RULES_FILE"
  save_iptables
}
