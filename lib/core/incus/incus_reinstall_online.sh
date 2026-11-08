#!/bin/bash
# Put Incus back from the internet (the stable Ubuntu package) after it was deleted or broken.
incus_reinstall_online() {
  echo "Reinstalling Incus from the internet..."
  apt-get update >/dev/null 2>&1 || true
  vpsforge_apt_install incus || { echo "ERROR: could not install Incus (check the internet connection)."; return 1; }
  systemctl enable --now incus.socket incus.service >/dev/null 2>&1 || true
  incus admin waitready --timeout=60 >/dev/null 2>&1 || true
  if incus info >/dev/null 2>&1; then
    echo "Incus is running again ($(incus --version 2>/dev/null)). Your VPSs and their data were not touched."
    return 0
  fi
  echo "ERROR: Incus was reinstalled but does not answer (try: systemctl status incus)."
  return 1
}
