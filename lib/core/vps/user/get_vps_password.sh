#!/bin/bash
# Retrieve the saved password of a VPS, defaulting to the root password.
get_vps_password() {
  local value
  value=$(incus config get "$1" user.vpsforge.password 2>/dev/null || true)
  echo "${value:-$ROOT_PASSWORD}"
}
