#!/bin/bash
# Ask: unlimited disk or a limit in GB (defaults to your last answer). Sets DISK_MODE_RESULT / DISK_VALUE_RESULT.
ask_disk_mode() {
  local available
  available=$(get_disk_available_for_vps "$1")
  echo "Total Disk: $(get_host_disk_total_gb)GB | Available for this VPS: ${available}GB"
  ask_mode_and_value "$1" disk DISK "Disk" "GB" "in GB, minimum 3, up to ${available}" is_valid_disk_value     "ERROR: Disk limit must be between 3GB and ${available}GB (available on host)."
}
