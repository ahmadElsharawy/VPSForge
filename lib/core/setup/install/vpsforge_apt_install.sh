#!/bin/bash
# apt-get install that REMEMBERS exactly which packages it added (the requested
# ones and every dependency pulled in), in $PRE_INSTALL_DIR/packages_installed.txt.
# "vpsforge uninstall" removes exactly that list, never anything else.
# It waits for the apt lock first, and retries once after "apt-get update" if the first try fails.
vpsforge_apt_install() {
  local before after rc record="$PRE_INSTALL_DIR/packages_installed.txt"
  mkdir -p "$PRE_INSTALL_DIR"
  wait_for_apt_lock
  before=$(mktemp); after=$(mktemp)
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$before"

  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    wait_for_apt_lock
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing "$@"
    rc=$?
  fi

  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$after"
  comm -13 "$before" "$after" >> "$record"
  sort -u "$record" -o "$record"
  rm -f "$before" "$after"
  return "$rc"
}
