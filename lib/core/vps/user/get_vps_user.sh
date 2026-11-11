#!/bin/bash
# Retrieve the configured username of a VPS, defaulting to root.
get_vps_user() {
  local value
  value=$(incus config get "$1" user.vpsforge.username 2>/dev/null || true)
  echo "${value:-root}"
}
