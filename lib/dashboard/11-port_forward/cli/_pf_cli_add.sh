#!/bin/bash
# Apply a new port-forwarding rule via iptables, update metadata, and persist to file.
#   _pf_cli_add <target_file> <protocol> <ext_ip> <ext_port> <int_ip> <int_port>
_pf_cli_add() {
  local target_file="${1:-}"
  shift || true
  [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward add <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }

  local protocol external_ip external_port internal_ip internal_port
  protocol=$(printf '%s' "${1:-TCP}" | tr '[:upper:]' '[:lower:]')
  external_ip="${2:-0.0.0.0}" external_port="${3:-}" internal_ip="${4:-}" internal_port="${5:-}"
  [ -n "$external_ip" ] || external_ip="0.0.0.0"
  [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
  [[ "$external_port" =~ ^[0-9]+$ ]]    || { echo "External port must be numeric."; return 1; }
  [[ "$internal_port" =~ ^[0-9]+$ ]]    || { echo "Internal port must be numeric."; return 1; }

  if port_forward_rule_conflicts "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
    echo "Rule already exists for $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
    return 0
  fi

  local proto target_vps
  for proto in $(resolve_protocols "$protocol"); do
    is_valid_port_forward_rule "$proto" "$external_ip" "$external_port" "$internal_port" || { echo "ERROR: invalid rule (IPv4, ports 1-65535, not 22/80/443)."; return 1; }
  done
  [[ "$internal_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: the internal address must be an IPv4 address."; return 1; }
  for proto in $(resolve_protocols "$protocol"); do
    port_forward_apply_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port" || { echo "ERROR: iptables refused the rule."; return 1; }
    port_forward_append_rule_to_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
  done
  save_iptables
  target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
  if [ -n "$target_vps" ]; then
    if [ "$internal_port" = "22" ] && [[ "$protocol" =~ ^(tcp|both)$ ]]; then
      incus config set "$target_vps" user.vpsforge.ssh_port "$external_port" 2>/dev/null || true
    fi
    sync_vps_metadata "$target_vps"
  fi
  echo "Port forward applied: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
}
