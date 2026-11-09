#!/bin/bash
_install_ssh() {
  local name="$1" ip="$2" port="$3"
  local ssh_install_ok=0 attempt

  for attempt in 1 2 3; do
    if incus exec "$name" -- sh -c '
      set -e
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
        echo "Unknown package manager."; exit 1
      fi
    '; then
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
  ' || {
    echo "Failed to enable SSH in $name."
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }
}
