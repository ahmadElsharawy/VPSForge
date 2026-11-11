#!/bin/bash
# Synchronize active iptables DNAT rules and inventory SSH ports with the rules file.
port_forward_auto_sync_active_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file" 2>/dev/null || true

  local tmpf
  tmpf=$(mktemp)
  touch "$tmpf"
  [ -f "$file" ] && cp "$file" "$tmpf"

  # 1. Capture any active iptables DNAT rules into the rules file if missing
  _capture_active_dnat_rules "$tmpf"

  # 2. Also ensure each container's SSH port from metadata exists in tmpf if active/saved
  _capture_inventory_ssh_ports "$tmpf"

  # 3. Apply all rules from tmpf into iptables (not while the owner has them disabled)
  local proto ext_ip ext_port int_ip int_port
  [ -f "${file}.disabled" ] || while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] || continue
    port_forward_apply_rule "$proto" "${ext_ip:-0.0.0.0}" "$ext_port" "$int_ip" "$int_port"
  done < "$tmpf"

  mv -f "$tmpf" "$file"
}
