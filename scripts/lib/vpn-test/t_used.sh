#!/bin/bash
# Verify that traffic count for a device increases after data transfer.
t_used() { vpn_list_devices "$S" | awk -F'|' '$1 == "phone" && $5 > 5000000 && $4 != "" { f = 1 } END { exit !f }'; }
