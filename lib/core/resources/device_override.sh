#!/bin/bash
# VPSForge v1.0.0 — Incus device override helper.

# Creates a per-instance override for an inherited Incus device if it does not
# already exist in the instance's local config.
ensure_device_override() {
  local name="$1" device="$2"

  if incus config show "$name" 2>/dev/null | awk '
      /^devices:/ {in_devices=1; next}
      in_devices && /^[^ ]/ {in_devices=0}
      in_devices && $0 ~ "^  '"$device"':$" {found=1}
      END {exit !found}
    '; then
    return 0
  fi

  incus config device override "$name" "$device" || {
    echo "ERROR: Failed to override device $device for $name."
    return 1
  }
}
