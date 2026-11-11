#!/bin/bash
# Print list of ports currently listening inside the container with default indicator.
#   _proxy_print_detected_ports <default_port> [ports...]
_proxy_print_detected_ports() {
  local default_port="$1"
  shift
  local idx label
  local -a ports=("$@")
  echo "Ports an app is listening on right now:"
  for idx in "${!ports[@]}"; do
    label=""; [ "${ports[$idx]}" = "$default_port" ] && label="  (default)"
    printf '   %d) %s%s\n' "$((idx + 1))" "${ports[$idx]}" "$label"
  done
}
