#!/bin/bash
# Renders the dashboard table and menu text to the terminal in full or refresh mode.
_dashboard_render() {
  local table_output="$1" mode="$2"
  local menu="
 1) Add            create new VPSs                  e.g. 2 servers with 512MB RAM each
 2) Delete         remove a VPS completely          (disk, snapshots, firewall rules)
 3) Start          power on                         e.g. web1   or   1,3
 4) Stop           power off
 5) Restart        stop and start again
 6) Reinstall      wipe to a clean OS               keeps IP, port, limits and login
 7) Edit VPS       RAM, CPU, disk, network, SSH port, login, name, IP, OS
 8) Details        everything about a VPS           limits, ports, domains, backups
 9) Shell          open a terminal inside a VPS
10) Connection     how to log in                    IP, port, user, password
11) Port Forward   open a server port to a VPS      e.g. 8080 -> 80
12) Domains & Reverse Proxy   https://app.mydomain.com -> an app inside a VPS
13) Snapshots & Backups       save a VPS now, restore it later, or clone it (instant copy)
14) Settings       refresh, network speed, updates, uninstall
15) Exit"

  # Clear the rest of every line, so nothing of the previous frame stays visible after a refresh.
  table_output="${table_output//$'
'/$'[K
'}"$'[K'
  menu="${menu//$'
'/$'[K
'}"

  if [ "$mode" = "refresh" ]; then
    printf "\033[H%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  else
    clear
    printf "%s\n%s\n\033[JChoice: " "$table_output" "$menu"
  fi
}
