#!/bin/bash
# Install openssh-server inside a guest container using its native package manager.
_install_guest_openssh_pkg() {
  local name="$1"
  incus exec "$name" -- sh -c '
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
  '
}
