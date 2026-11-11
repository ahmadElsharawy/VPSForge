#!/bin/bash
# Command-line interface for port forwarding management (add, edit, delete, import, export, status).
port_forward_cli() {
  local action="${1:-}"
  local target_file="$PORT_FORWARD_RULES_FILE"
  [ $# -gt 0 ] && shift

  case "$action" in
    add)        _pf_cli_add "$target_file" "$@";;
    edit)       _pf_cli_edit "$@";;
    delete)     _pf_cli_delete "$target_file" "$@";;
    save)       port_forward_save_rules_to_file "${1:-$target_file}";;
    export)     port_forward_save_rules_to_file "${1:-$target_file}"; echo "Exported rules to ${1:-$target_file}";;
    load|import) port_forward_load_rules_from_file "${1:-$target_file}";;
    delete-all) port_forward_delete_all_rules "${1:-$target_file}";;
    disable)    port_forward_disable_rules "${1:-$target_file}";;
    enable)     port_forward_enable_rules "${1:-$target_file}";;
    status)     port_forward_status;;
    list)       port_forward_list_rules;;
    *)
      echo "Usage: vpsforge port-forward add|edit|delete|save|load|export|import|delete-all|enable|disable|list|status [args]"
      return 1
      ;;
  esac
}
