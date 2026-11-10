#!/bin/bash
change_vps_username() {
  local name="$1" new_user="$2"
  [ -n "$name" ] && [ -n "$new_user" ] || return 1

  if ! is_valid_username "$new_user"; then
    echo "ERROR: Invalid username '$new_user'. Use lowercase letters, digits, '_' or '-' (max 32, must not start with a digit)."
    return 1
  fi

  incus exec "$name" --env NEW_USER="$new_user" -- sh -c '
    set -e
    if ! id "$NEW_USER" >/dev/null 2>&1; then
      if command -v useradd >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$NEW_USER" 2>/dev/null || useradd -m "$NEW_USER"
      else
        adduser -D -s /bin/sh "$NEW_USER"
      fi
    fi
    if command -v usermod >/dev/null 2>&1; then
      usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null || true
    else
      addgroup "$NEW_USER" wheel 2>/dev/null || true
    fi
    mkdir -p /etc/sudoers.d
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEW_USER"
    chmod 0440 "/etc/sudoers.d/$NEW_USER"
    cp -rn /root/.ssh "/home/$NEW_USER/.ssh" 2>/dev/null || true
    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER" 2>/dev/null || true
  ' || { echo "ERROR: Failed to create user $new_user in $name."; return 1; }

  printf '%s:%s\n' "$new_user" "$(get_vps_password "$name")" | incus exec "$name" -- chpasswd >/dev/null 2>&1 || echo "WARNING: could not set the password of $new_user."
  set_vps_user "$name" "$new_user"
  echo "Username changed to '$new_user' for $name."
}
