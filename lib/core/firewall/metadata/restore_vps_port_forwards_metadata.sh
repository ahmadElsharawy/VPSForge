#!/bin/bash
# Restore port forwarding rules for a VPS from container metadata or rules file.
restore_vps_port_forwards_metadata() {
  local name="$1" ip rules
  ip=$(get_ip "$name" 2>/dev/null || true)
  [ -n "$ip" ] || return 0

  # 1. Try to restore from the container's own metadata rules (enables restoration on new servers or if IP changed!)
  rules=$(incus config get "$name" user.vpsforge.port_forwards.rules 2>/dev/null || true)
  if [ -n "$rules" ]; then
    _apply_metadata_port_rules "$ip" "$rules"
    save_iptables
    return 0
  fi

  # 2. Fallback to the original host-rules-file lookup
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 0
  local proto ext_ip ext_port int_ip int_port
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ "$int_ip" = "$ip" ] || continue
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
  done < "$PORT_FORWARD_RULES_FILE"
  save_iptables
}
