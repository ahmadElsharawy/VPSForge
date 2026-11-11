#!/bin/bash
# Configure SSH daemon settings and start SSH service inside a guest container.
_enable_guest_sshd() {
  local name="$1"
  incus exec "$name" -- sh -c '
    set -e
    if [ -d /etc/ssh/sshd_config.d ]; then
      mkdir -p /etc/ssh/sshd_config.d
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" > /etc/ssh/sshd_config.d/00-vpsforge-root-login.conf
    else
      mkdir -p /etc/ssh
      touch /etc/ssh/sshd_config
      grep -v -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp || true
      mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
      printf "PermitRootLogin yes\nPasswordAuthentication yes\n" >> /etc/ssh/sshd_config
    fi

    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
      systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    elif command -v rc-update >/dev/null 2>&1; then
      rc-update add sshd default 2>/dev/null || true
      /etc/init.d/sshd restart 2>/dev/null || true
    fi
  '
}
