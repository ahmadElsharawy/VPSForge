#!/bin/bash
change_vps_password() {
  local name="$1" new_pass="$2" user
  [ -n "$name" ] && [ -n "$new_pass" ] || return 1
  case "$new_pass" in
    *$'\n'*|*:*) echo "ERROR: Password must not contain ':' or newlines."; return 1;;
  esac
  user=$(get_vps_user "$name")

  printf '%s:%s\n' "$user" "$new_pass" | incus exec "$name" -- chpasswd || {
    echo "ERROR: Failed to change password in $name."
    return 1
  }
  # Also update root password if user is not root
  if [ "$user" != "root" ]; then
    printf 'root:%s\n' "$new_pass" | incus exec "$name" -- chpasswd 2>/dev/null || true
  fi

  set_vps_password "$name" "$new_pass"
  echo "Password changed for $name."
}
