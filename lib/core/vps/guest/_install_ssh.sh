#!/bin/bash
# Install and configure OpenSSH in a new VPS container, rolling back on failure.
_install_ssh() {
  local name="$1" ip="$2" port="$3"
  local ssh_install_ok=0 attempt

  for attempt in 1 2 3; do
    if _install_guest_openssh_pkg "$name"; then
      ssh_install_ok=1
      break
    fi
    echo "SSH installation attempt $attempt/3 failed for $name. Retrying..."
    sleep 3
  done

  [ "$ssh_install_ok" -eq 1 ] || {
    echo "Failed to install openssh-server in $name after 3 attempts."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  printf 'root:%s\n' "$ROOT_PASSWORD" | incus exec "$name" -- chpasswd || echo "WARNING: could not set the root password in $name."

  _enable_guest_sshd "$name" || {
    echo "Failed to enable SSH in $name."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }
}
