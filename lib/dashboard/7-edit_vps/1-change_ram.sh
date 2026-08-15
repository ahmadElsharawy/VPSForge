#!/bin/bash
# VPSForge v1.0.0 — Edit: Change RAM.
edit_change_ram() { ask_ram_mode "$1" && set_ram_mode_for_vps "$1" "$RAM_MODE_RESULT" "$RAM_VALUE_RESULT"; }
