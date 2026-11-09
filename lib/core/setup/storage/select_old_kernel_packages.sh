#!/bin/bash
# From a list of installed package names (stdin), print the kernel packages that are NOT needed:
# every kernel version except the running one and the newest installed one.
#   select_old_kernel_packages <running_release>   e.g. 7.0.0-1013-oracle
select_old_kernel_packages() {
  local running="${1:?running kernel}" pkg ver newest
  local -a pkgs=() vers=()
  while read -r pkg; do
    [[ "$pkg" =~ ^linux-(image|image-unsigned|modules|modules-extra|headers|tools|buildinfo)-([0-9]+\.[0-9]+\.[0-9]+-[0-9]+-[a-z0-9]+)$ ]] || continue
    pkgs+=("$pkg"); vers+=("${BASH_REMATCH[2]}")
  done
  [ "${#pkgs[@]}" -gt 0 ] || return 0
  newest=$(printf '%s\n' "${vers[@]}" | sort -uV | tail -n 1)
  local i
  for i in "${!pkgs[@]}"; do
    ver="${vers[$i]}"
    [ "$ver" = "$running" ] && continue
    [ "$ver" = "$newest" ] && continue
    echo "${pkgs[$i]}"
  done
}
