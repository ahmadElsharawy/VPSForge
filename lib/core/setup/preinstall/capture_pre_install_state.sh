#!/bin/bash
# Record the host state before VPSForge changes anything (once, on first setup):
# firewall rules, which packages already existed, and the ip_forward value.
# "vpsforge uninstall" uses this to restore the server exactly as it was.
capture_pre_install_state() {
  [ -d "$PRE_INSTALL_DIR" ] && return 0
  mkdir -p "$PRE_INSTALL_DIR" || return 0

  iptables-save > "$PRE_INSTALL_DIR/iptables.rules" 2>/dev/null || true
  sysctl -n net.ipv4.ip_forward > "$PRE_INSTALL_DIR/ip_forward" 2>/dev/null || true

  # Remember whether ufw already allowed 80/443, so uninstall removes only what we added.
  if command -v ufw >/dev/null 2>&1; then
    ufw status 2>/dev/null > "$PRE_INSTALL_DIR/ufw.status" || true
  fi

  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$PRE_INSTALL_DIR/packages_all.txt"

  local pkg
  : > "$PRE_INSTALL_DIR/packages_present.txt"
  for pkg in $VPSFORGE_PACKAGES; do
    dpkg -s "$pkg" >/dev/null 2>&1 && echo "$pkg" >> "$PRE_INSTALL_DIR/packages_present.txt"
  done
  date -u '+%Y-%m-%d %H:%M:%S UTC' > "$PRE_INSTALL_DIR/captured_at"
}
