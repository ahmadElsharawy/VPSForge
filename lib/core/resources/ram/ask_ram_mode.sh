#!/bin/bash
# Ask: unlimited RAM or a limit (defaults to your last answer). Sets RAM_MODE_RESULT / RAM_VALUE_RESULT.
ask_ram_mode() {
  echo "Total RAM: $(get_host_total_ram_mb)MB | Available: $(get_host_available_ram_mb)MB"
  ask_mode_and_value "$1" ram RAM "RAM" "MB" "in MB, minimum $MIN_RAM_MB" is_valid_ram_value "Invalid RAM limit."
}
