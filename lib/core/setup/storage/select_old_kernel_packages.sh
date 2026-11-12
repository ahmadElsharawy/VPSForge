#!/bin/bash
# From a list of installed package names (stdin), print the kernel packages that are NOT needed:
# every kernel version except the running one and the newest installed one.
#   select_old_kernel_packages <running_release>   e.g. 7.0.0-1013-oracle
select_old_kernel_packages() {
  local running="${1:?running kernel}" pkg ver newest
  local -a pkgs=() vers=()
  # Versions are compared without the flavour ("7.0.0-1013-oracle" -> "7.0.0-1013"), because the
  # shared header/tool packages carry none: linux-oracle-6.17-headers-6.17.0-1011.
  while read -r pkg; do
    if [[ "$pkg" =~ ^linux-(image|image-unsigned|modules|modules-extra|headers|tools|buildinfo)-([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)-[a-z0-9]+$ ]]; then
      pkgs+=("$pkg"); vers+=("${BASH_REMATCH[2]}")
    elif [[ "$pkg" =~ ^linux-[a-z0-9]+-[0-9]+\.[0-9]+-(headers|tools)-([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)$ ]]; then
      pkgs+=("$pkg"); vers+=("${BASH_REMATCH[2]}")
    fi
  done
  running="${running%-*}"
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
