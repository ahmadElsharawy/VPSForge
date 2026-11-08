#!/bin/bash
# Edit: change a VPS's SSH port (Enter repeats the last port you typed).
edit_change_port() {
  local name="${1:-}" port last
  last=$(pref_get ssh_port_last "")
  show_example "2222  (a free port, 1024-65535, used to log in:  ssh root@SERVER -p 2222)"
  read -r -p "New SSH port${last:+ [Enter=$last]} [0=Back]: " port
  [ "$port" = "0" ] && return
  port="${port:-$last}"
  [ -n "$port" ] || return
  change_vps_port "$name" "$port" && pref_set ssh_port_last "$port"
}
