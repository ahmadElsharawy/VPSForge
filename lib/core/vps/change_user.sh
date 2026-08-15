#!/bin/bash
# VPSForge v1.0.0 — VPS username and password modification.

change_vps_username() {
  local name="$1" new_user="$2"
  [ -n "$name" ] && [ -n "$new_user" ] || return 1

  incus exec "$name" -- sh -c "
    set -e
    if ! id '$new_user' >/dev/null 2>&1; then
      if command -v useradd >/dev/null 2>&1; then
        useradd -m -s /bin/bash '$new_user' 2>/dev/null || useradd -m '$new_user'
      else
        adduser -D -s /bin/sh '$new_user'
      fi
    fi
    if command -v usermod >/dev/null 2>&1; then
      usermod -aG sudo '$new_user' 2>/dev/null || usermod -aG wheel '$new_user' 2>/dev/null || true
    else
      addgroup '$new_user' wheel 2>/dev/null || true
    fi
    mkdir -p /etc/sudoers.d
    echo '$new_user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$new_user
    chmod 0440 /etc/sudoers.d/$new_user
    cp -rn /root/.ssh /home/$new_user/.ssh 2>/dev/null || true
    chown -R $new_user:$new_user /home/$new_user 2>/dev/null || true
  " || { echo "ERROR: Failed to create user $new_user in $name."; return 1; }

  set_vps_user "$name" "$new_user"
  echo "Username changed to '$new_user' for $name."
}

change_vps_password() {
  local name="$1" new_pass="$2" user
  [ -n "$name" ] && [ -n "$new_pass" ] || return 1
  user=$(get_vps_user "$name")

  incus exec "$name" -- sh -c "echo '${user}:${new_pass}' | chpasswd" || {
    echo "ERROR: Failed to change password in $name."
    return 1
  }
  # Also update root password if user is not root
  [ "$user" = "root" ] || incus exec "$name" -- sh -c "echo 'root:${new_pass}' | chpasswd" 2>/dev/null || true

  set_vps_password "$name" "$new_pass"
  echo "Password changed for $name."
}
