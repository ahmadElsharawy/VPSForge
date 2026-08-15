#!/bin/bash

port_forward_cli() {
  local action="${1:-}"
  local protocol external_ip external_port internal_ip internal_port
  local target_file="$PORT_FORWARD_RULES_FILE"

  case "$action" in
    add)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward add <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]]    || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]]    || { echo "Internal port must be numeric."; return 1; }

      if port_forward_rule_conflicts "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"; then
        echo "Rule already exists for $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
        return 0
      fi

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_apply_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_metadata "$target_vps"
      echo "Port forward applied: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    edit)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward edit <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "$external_port" =~ ^[0-9]+$ ]]    || { echo "External port must be numeric."; return 1; }
      [[ "$internal_port" =~ ^[0-9]+$ ]]    || { echo "Internal port must be numeric."; return 1; }

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_delete_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_apply_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_append_rule_to_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_metadata "$target_vps"
      echo "Port forward updated: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    delete)
      [ $# -ge 5 ] || { echo "Usage: vpsforge port-forward delete <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
      [[ "$protocol" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }

      local proto target_vps
      for proto in $(resolve_protocols "$protocol"); do
        port_forward_delete_rule "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
        port_forward_remove_rule_from_file "$target_file" "$proto" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
      done
      save_iptables
      target_vps=$(get_vps_name_by_ip "$internal_ip" 2>/dev/null || true)
      [ -n "$target_vps" ] && sync_vps_metadata "$target_vps"
      echo "Port forward removed: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    save)       port_forward_save_rules_to_file "${2:-$target_file}";;
    export)     port_forward_save_rules_to_file "${2:-$target_file}"; echo "Exported rules to ${2:-$target_file}";;
    load|import) port_forward_load_rules_from_file "${2:-$target_file}";;
    delete-all) port_forward_delete_all_rules "${2:-$target_file}";;
    disable)    port_forward_disable_rules "${2:-$target_file}";;
    enable)     port_forward_enable_rules "${2:-$target_file}";;
    status)     port_forward_status;;
    list)       port_forward_list_rules;;
    *)
      echo "Usage: vpsforge port-forward add|edit|delete|save|load|export|import|delete-all|enable|disable|list|status [args]"
      return 1
      ;;
  esac
}
