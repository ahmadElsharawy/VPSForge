#!/bin/bash
# Cap the system log (journal) at 200MB for good, so it can never fill the server's disk.
# "vpsforge uninstall" removes this file.
limit_system_journal() {
  local conf=/etc/systemd/journald.conf.d/vpsforge.conf
  command -v journalctl >/dev/null 2>&1 || return 0
  [ -f "$conf" ] && return 0
  mkdir -p /etc/systemd/journald.conf.d 2>/dev/null || return 0
  printf '[Journal]\nSystemMaxUse=200M\n' > "$conf"
  systemctl restart systemd-journald >/dev/null 2>&1 || true
}
