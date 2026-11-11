#!/bin/bash
# Does this VPS get a public SSH forward? Returns 1 only when it was created without one (flag is exactly n).
#   vps_ssh_forward_enabled <name>
vps_ssh_forward_enabled() {
  local name="${1:?name}" flag
  flag=$(incus config get "$name" user.vpsforge.ssh_forward 2>/dev/null || true)
  [ "$flag" != "n" ]
}
