#!/bin/bash
# From the given module names, print (comma separated) only those this server's
# kernel can really load or already has built in. Asking Incus to load a module the
# kernel does not have makes the VPS refuse to start, so unknown ones are skipped.
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
