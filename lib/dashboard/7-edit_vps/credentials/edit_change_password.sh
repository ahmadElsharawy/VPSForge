#!/bin/bash
# VPSForge v1.0.0 — Edit: Change Password.

# Prompts for a new password and updates it on the specified VPS.
edit_change_password() {
  local name="${1:-}" pass
  read -r -s -p "New password [0=Back]: " pass; echo
  { [ "$pass" = "0" ] || [ -z "$pass" ]; } && return
  change_vps_password "$name" "$pass"
}
