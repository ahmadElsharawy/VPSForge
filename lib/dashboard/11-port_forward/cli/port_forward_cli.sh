#!/bin/bash

port_forward_cli() {
  local action="${1:-}"
  local protocol external_ip external_port internal_ip internal_port
  local target_file="$PORT_FORWARD_RULES_FILE"

  case "$action" in
    add)
      [ $# -ge 6 ] || { echo "Usage: vpsforge port-forward add <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-0.0.0.0}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
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
      [ -n "$target_vps" ] && sync_vps_metadata "$target_vps"
      echo "Port forward applied: $protocol $external_ip:$external_port -> $internal_ip:$internal_port"
      ;;

    edit)
      # Old rule (5 values) followed by the new rule (5 values): the old one is
      # removed only after the new one is checked, and comes back if adding fails.
      [ $# -ge 11 ] || { echo "Usage: vpsforge port-forward edit <old: proto ext_ip ext_port int_ip int_port> <new: proto ext_ip ext_port int_ip int_port>"; return 1; }
      local old_rule=("$2" "$3" "$4" "$5" "$6") new_rule=("$7" "$8" "$9" "${10}" "${11}")
      local new_proto
      new_proto=$(printf '%s' "${new_rule[0]}" | tr '[:upper:]' '[:lower:]')
      [[ "$new_proto" =~ ^(tcp|udp|both)$ ]] || { echo "Protocol must be tcp, udp, or both."; return 1; }
      [[ "${new_rule[2]}" =~ ^[0-9]+$ && "${new_rule[4]}" =~ ^[0-9]+$ ]] || { echo "Ports must be numeric."; return 1; }
      [[ "${new_rule[3]}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: the internal address must be an IPv4 address."; return 1; }
      local proto
      for proto in $(resolve_protocols "$new_proto"); do
        is_valid_port_forward_rule "$proto" "${new_rule[1]}" "${new_rule[2]}" "${new_rule[4]}" || { echo "ERROR: invalid new rule (IPv4, ports 1-65535, not 22/80/443). Nothing was changed."; return 1; }
      done
      port_forward_cli delete "${old_rule[@]}" || return 1
      if ! port_forward_cli add "${new_rule[@]}"; then
        echo "Adding the new rule failed; putting the old rule back."
        port_forward_cli add "${old_rule[@]}"
        return 1
      fi
      ;;

    delete)
      [ $# -ge 6 ] || { echo "Usage: vpsforge port-forward delete <tcp|udp|both> <external_ip|0.0.0.0> <external_port> <internal_ip> <internal_port>"; return 1; }
      protocol=$(printf '%s' "${2:-TCP}" | tr '[:upper:]' '[:lower:]')
      external_ip="${3:-0.0.0.0}" external_port="${4:-}" internal_ip="${5:-}" internal_port="${6:-}"
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
