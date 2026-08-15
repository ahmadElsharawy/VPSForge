#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Network Speed.
edit_change_network() { ask_network_mode "$1" && set_network_mode_for_vps "$1" "$NETWORK_MODE_RESULT" "$NETWORK_VALUE_RESULT"; }
