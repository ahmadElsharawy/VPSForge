#!/bin/bash
# Delete a port-forward rule from iptables, update metadata, and remove from file.
#   _pf_cli_delete <target_file> <protocol> <ext_ip> <ext_port> <int_ip> <int_port>
_pf_cli_delete() {
  local target_file="${1:-}"
  shift || true
  [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward delete <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }

  local protocol external_ip external_port internal_ip internal_port
  protocol=$(printf '%s' "${1:-TCP}" | tr '[:upper:]' '[:lower:]')
  external_ip="${2:-0.0.0.0}" external_port="${3:-}" internal_ip="${4:-}" internal_port="${5:-}"
  [ -n "$external_ip" ] || external_ip="0.0.0.0"
  [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }

  local proto target_vps
  for proto in $(resolve_protocols "$protocol"); do
    port_forward_delete_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
    port_forward_remove_rule_from_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
  done
  save_iptables
  target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
  if [ -n "$target_vps" ]; then
    if [ "$internal_port" = "22" ]; then
      incus config unset "$target_vps" user.vpsforge.ssh_port 2>/dev/null || true
    fi
    sync_vps_metadata "$target_vps"
  fi
  echo "Port forward removed: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
}
