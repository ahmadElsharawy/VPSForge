#!/bin/bash
# Check device state (on, off-data, off-time) for a given device.
t_state() { vpn_list_devices "$S" | awk -F'|' -v n="$1" -v s="$2" '$1 == n && $8 == s { f = 1 } END { exit !f }'; }
