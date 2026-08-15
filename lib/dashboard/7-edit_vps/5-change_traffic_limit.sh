#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Traffic Data Limit.
edit_change_traffic() { ask_traffic_mode "$1" && set_traffic_mode_for_vps "$1" "$TRAFFIC_MODE_RESULT" "$TRAFFIC_RX_RESULT" "$TRAFFIC_TX_RESULT"; }
