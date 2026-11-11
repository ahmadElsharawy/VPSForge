#!/bin/bash
# Install Xray (official release, checksum verified) and qrencode inside a VPS.
#   vpn_install_packages <vps>
vpn_install_packages() {
  local vps="${1:?vps}" attempt
  for attempt in 1 2 3; do
    if _vpn_install_guest "$vps"; then
      return 0
    fi
    echo "Xray install attempt $attempt/3 failed for $vps. Retrying..."
    sleep 3
  done
  echo "ERROR: could not install Xray inside $vps."
  return 1
}
