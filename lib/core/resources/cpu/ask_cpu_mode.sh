#!/bin/bash
# Ask: all CPU cores or a limit, then CPU usage cap. Sets CPU_MODE_RESULT / CPU_VALUE_RESULT.
ask_cpu_mode() {
  while :; do
    ask_mode_and_value "$1" cpu CPU "CPU" " core(s)" "cores, example: 1, up to $(get_host_cpu_count)" is_valid_cpu_value \
      "ERROR: This server has only $(get_host_cpu_count) CPU core(s). Allowed range: 1-$(get_host_cpu_count)." || return 1
    if ask_cpu_allowance "$1"; then
      CPU_VALUE_RESULT="${CPU_VALUE_RESULT}@${CPU_ALLOWANCE_RESULT}"
      return 0
    fi
  done
}
