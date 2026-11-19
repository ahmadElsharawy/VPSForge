#!/bin/bash
# Asks for CPU usage cap percentage (1-100, 0=Back). Sets CPU_ALLOWANCE_RESULT.
ask_cpu_allowance() {
  local target="${1:-}" default val
  default=$(pref_get cpu_allowance 70)
  while :; do
    read -r -p "CPU usage cap in percent (1-100) [Enter=$default]: " val
    [ "$val" = "0" ] && return 1
    val="${val:-$default}"
    if is_valid_cpu_allowance "$val"; then
      CPU_ALLOWANCE_RESULT="$val"
      pref_set cpu_allowance "$val"
      return 0
    fi
    echo "ERROR: CPU usage cap must be a whole number between 1 and 100."
  done
}
