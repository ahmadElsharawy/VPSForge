#!/bin/bash
# VPSForge v1.0.0 — Edit: Reinstall / Change OS Image.

edit_reinstall_image() {
  local name="$1"
  ask_ubuntu_version "$name" || return
  reinstall_single_vps_core "$name" "$SELECTED_IMAGE"
}
