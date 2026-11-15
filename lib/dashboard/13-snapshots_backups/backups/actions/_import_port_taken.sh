#!/bin/bash
# Succeed if <proto>/<port> was already chosen for another rule of this same import (rules_to_apply),
# so two rules of one backup never end up on one public port.
#   _import_port_taken <proto> <port>
_import_port_taken() {
  local proto="$1" port="$2" r
  for r in "${rules_to_apply[@]}"; do
    [ "$(cut -d'|' -f1 <<< "$r")" = "$proto" ] && [ "$(cut -d'|' -f3 <<< "$r")" = "$port" ] && return 0
  done
  return 1
}
