#!/bin/bash
# The login name of a VPS (root when none is saved).
get_vps_user() {
  local value
  value=$(incus config get "$1" user.vpsforge.username 2>/dev/null || true)
  echo "${value:-root}"
}
