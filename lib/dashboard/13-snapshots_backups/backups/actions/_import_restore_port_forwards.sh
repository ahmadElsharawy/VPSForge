#!/bin/bash
# Restore saved user credentials, SSH port, and forwarded port rules on imported container.
_import_restore_port_forwards() {
  echo "[  95% ] Restoring port forwarding rules..."
  add_forward_rule "$new_ip" "$new_port" >/dev/null 2>&1 || true
  set_vps_user "$target_name" "${kept_user:-root}"
  set_vps_password "$target_name" "${kept_pw:-$ROOT_PASSWORD}"
  set_vps_saved_port "$target_name" "$new_port"

  if [ "${#rules_to_apply[@]}" -gt 0 ]; then
    local r proto ext_ip ext_port int_port
    for r in "${rules_to_apply[@]}"; do
      IFS='|' read -r proto ext_ip ext_port int_port <<< "$r"
      port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$new_ip" "$int_port"
      echo "${proto}|${ext_ip}|${ext_port}|${new_ip}|${int_port}" >> "$PORT_FORWARD_RULES_FILE"
    done
    save_iptables
  fi
}
