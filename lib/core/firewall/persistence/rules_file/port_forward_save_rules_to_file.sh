#!/bin/bash
port_forward_save_rules_to_file() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  port_forward_auto_sync_active_rules "$file"
  echo "Rules saved to $file."
}
