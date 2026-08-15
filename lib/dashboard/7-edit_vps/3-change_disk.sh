#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Disk.
edit_change_disk() { ask_disk_mode "$1" && set_disk_mode_for_vps "$1" "$DISK_MODE_RESULT" "$DISK_VALUE_RESULT"; }
