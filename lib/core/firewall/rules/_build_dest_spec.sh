#!/bin/bash
_build_dest_spec() {
  local ext_ip="${1:-}"
  if [ -n "$ext_ip" ] && [ "$ext_ip" != "0.0.0.0" ] && [ "$ext_ip" != "any" ]; then
    echo "-d $ext_ip"
  else
    echo "! -i incusbr0"
  fi
}
