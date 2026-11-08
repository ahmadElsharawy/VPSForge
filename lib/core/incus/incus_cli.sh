#!/bin/bash
# vpsforge incus <status|pin|unpin|selftest|repair>
incus_cli() {
  case "${1:-status}" in
    status)   incus_status;;
    pin)      incus_pin;;
    unpin)    incus_unpin;;
    selftest) incus_compat_check;;
    repair)   ensure_incus_alive;;
    *) echo "Usage: vpsforge incus status|pin|unpin|selftest|repair"; return 1;;
  esac
}
