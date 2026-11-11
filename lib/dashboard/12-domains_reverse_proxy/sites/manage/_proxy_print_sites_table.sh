#!/bin/bash
# Print formatted table of configured proxy routes.
#   _proxy_print_sites_table [routes...]
_proxy_print_sites_table() {
  local route vps domain path target shown i=0
  printf ' %-3s %-38s %-12s %s\n' "#" "WEBSITE" "VPS" "GOES TO"
  for route in "$@"; do
    i=$((i + 1))
    IFS='|' read -r vps domain path target _ <<< "$route"
    shown="https://${domain}"
    [ "$path" != "/" ] && shown="${shown}${path%\*}"
    printf ' %-3s %-38s %-12s %s\n' "$i" "$shown" "$vps" "${target#*://}"
  done
}
