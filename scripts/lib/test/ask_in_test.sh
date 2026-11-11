#!/bin/bash
# Helper to test ask_mode_and_value with simulated user input.
ask_in_test() { printf '2
512
' | ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value >/dev/null; echo "$RAM_MODE_RESULT $RAM_VALUE_RESULT"; }
