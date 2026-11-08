#!/bin/bash
# Ask: all CPU cores or a limit (defaults to your last answer). Sets CPU_MODE_RESULT / CPU_VALUE_RESULT.
ask_cpu_mode() {
  ask_mode_and_value "$1" cpu CPU "CPU" " core(s)" "cores, 1-$(get_host_cpu_count)" is_valid_cpu_value     "ERROR: This server has only $(get_host_cpu_count) CPU core(s). Allowed range: 1-$(get_host_cpu_count)."
}
