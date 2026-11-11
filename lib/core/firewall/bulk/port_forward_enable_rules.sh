#!/bin/bash
# Re-enable port forward rules from the saved rules file.
port_forward_enable_rules() {
  local file="${1:-$PORT_FORWARD_RULES_FILE}"
  rm -f "${file}.disabled"
  port_forward_load_rules_from_file "$file"
  echo "Port forward rules re-enabled."
}
