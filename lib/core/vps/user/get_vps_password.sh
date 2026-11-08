#!/bin/bash
# The saved password of a VPS (the default one when none is saved).
get_vps_password() {
  local value
  value=$(incus config get "$1" user.vpsforge.password 2>/dev/null || true)
  echo "${value:-$ROOT_PASSWORD}"
}
