#!/bin/bash
# True when <name> is a plain host name that can be a Reality SNI (like www.microsoft.com).
#   is_valid_vpn_sni <name>
is_valid_vpn_sni() {
  local name="${1:-}"
  [ "${#name}" -le 253 ] || return 1
  [[ "$name" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]]
}
