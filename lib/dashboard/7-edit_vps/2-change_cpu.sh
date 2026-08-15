#!/bin/bash
# VPSForge v1.0.0 — Edit: Change CPU.
edit_change_cpu() { ask_cpu_mode "$1" && set_cpu_mode_for_vps "$1" "$CPU_MODE_RESULT" "$CPU_VALUE_RESULT"; }
