#!/bin/bash
# VPSForge v1.0.0 — Shared helper functions.

# ── Helpers ──────────────────────────────────────────────────────────────────

pause() { read -r -p "Press Enter to continue..."; }

# Convert a human-readable RAM string to plain megabytes.
ram_mb() {
  case "$1" in
    *MiB)      echo "${1%MiB}";;
    *GiB)      echo $(( ${1%GiB} * 1024 ));;
    *MB)       echo "${1%MB}";;
    *GB)       echo $(( ${1%GB} * 1000 ));;
    Unlimited|"") echo 0;;
    *)         echo "$1";;
  esac
}
