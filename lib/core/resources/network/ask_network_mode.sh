#!/bin/bash
# Ask: full speed or a limit in Mbit (defaults to your last answer). Sets NETWORK_MODE_RESULT / NETWORK_VALUE_RESULT.
ask_network_mode() {
  echo "Total Network Speed: $(get_total_network_mbit) Mbit"
  ask_mode_and_value "$1" network NETWORK "Network" " Mbit" "in Mbit, example: 100 = 100 Mbit/s, up to 100000" is_valid_network_value "Invalid network limit."
}
