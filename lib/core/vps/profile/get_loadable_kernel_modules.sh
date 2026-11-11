#!/bin/bash
# From the given module names, print comma-separated only those the host kernel supports.
#   get_loadable_kernel_modules overlay br_netfilter tun ...
get_loadable_kernel_modules() {
  local module list=""
  for module in "$@"; do
    if [ -d "/sys/module/$module" ] || modprobe -n -q "$module" >/dev/null 2>&1; then
      list="${list:+$list,}$module"
    fi
  done
  echo "$list"
}
