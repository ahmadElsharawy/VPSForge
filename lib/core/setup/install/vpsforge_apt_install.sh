#!/bin/bash
# apt-get install that REMEMBERS exactly which packages it added (the requested
# ones and every dependency pulled in), in $PRE_INSTALL_DIR/packages_installed.txt.
# "vpsforge uninstall" removes exactly that list, never anything else.
vpsforge_apt_install() {
  local before after rc record="$PRE_INSTALL_DIR/packages_installed.txt"
  mkdir -p "$PRE_INSTALL_DIR"
  before=$(mktemp); after=$(mktemp)
  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$before"

  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
  rc=$?

  dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | sort > "$after"
  comm -13 "$before" "$after" >> "$record"
  sort -u "$record" -o "$record"
  rm -f "$before" "$after"
  return "$rc"
}
