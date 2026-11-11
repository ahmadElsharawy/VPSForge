#!/bin/bash
# Install and configure OpenSSH server inside a guest container for root access.
_configure_guest_sshd() {
  local name="$1"
  incus exec "$name" -- sh -c '
    set -e
    if ! command -v sshd >/dev/null 2>&1; then
      if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        mkdir -p /etc/apt/apt.conf.d
        printf "Acquire::ForceIPv4 \"true\";\n" > /etc/apt/apt.conf.d/99force-ipv4
        apt-get -o Acquire::ForceIPv4=true update
        apt-get -o Acquire::ForceIPv4=true install -y openssh-server
      elif command -v apk >/dev/null 2>&1; then
        apk update
        apk add --no-cache openssh-server openssh
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm openssh
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y openssh-server
      elif command -v yum >/dev/null 2>&1; then
        yum install -y openssh-server
      else
        echo "Unknown package manager."
      fi
    fi

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
