#!/bin/bash
# Finalize SSH forwarding, credentials, metadata, and report creation status.
#   _finalize_vps_access <name> <ip> <port> <open_ssh>
_finalize_vps_access() {
  local name="$1" ip="$2" port="$3" open_ssh="$4"

  set_vps_user "$name" "root"
  set_vps_password "$name" "$ROOT_PASSWORD"

  if [[ "${open_ssh,,}" =~ ^y ]]; then
    add_forward_rule "$ip" "$port"
    set_vps_saved_port "$name" "$port"
    sync_vps_metadata "$name"
    echo "Done: ssh root@$PUBLIC_IP -p $port"
  else
    incus config set "$name" user.vpsforge.ssh_forward=n   # remembered: no public SSH forward is added later
    sync_vps_metadata "$name"
    echo "Done: VPS $name created (SSH external forwarding disabled, accessible via Shell / Internal IP $ip:22)"
  fi
  mark_vps_state "$name" ""
  pending_operation_clear "$name"
}
