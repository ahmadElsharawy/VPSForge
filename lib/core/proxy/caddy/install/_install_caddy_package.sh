#!/bin/bash
# Download repository signing keys and install Caddy package via apt.
_install_caddy_package() {
  echo "Installing Caddy..."
  wait_for_apt_lock
  apt-get update >/dev/null 2>&1
  vpsforge_apt_install debian-keyring debian-archive-keyring apt-transport-https curl gnupg >/dev/null 2>&1

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
    gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
    tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null

  wait_for_apt_lock
  apt-get update >/dev/null 2>&1
  vpsforge_apt_install caddy >/dev/null 2>&1

  if ! command -v caddy >/dev/null 2>&1; then
    echo "ERROR: Caddy installation failed. Check the internet connection and run again." >&2
    return 1
  fi
  return 0
}
