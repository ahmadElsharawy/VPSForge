#!/bin/bash
# Remove every website block that has no route left (no reverse_proxy inside) from a Caddy file,
# and print the domain of each block removed. A VPS's file can hold several domains, so removing
# the last route of the second domain must not leave an empty "domain { }" behind.
#   caddy_drop_empty_sites <caddy_file>
caddy_drop_empty_sites() {
  local conf="${1:?caddy file}" tmp_file
  [ -f "$conf" ] || return 0
  tmp_file=$(mktemp) || return 1
  awk -v out="$tmp_file" '
    function flush() {
      if (nb == 0) return
      if (has_route) { for (i = 1; i <= nb; i++) print buf[i] > out }
      else { d = buf[1]; sub(/[[:space:]]*\{.*/, "", d); sub(/,.*/, "", d); print d }
      nb = 0; has_route = 0
    }
    {
      line = $0
      if (depth == 0 && line ~ /^[^[:space:]#].*\{[[:space:]]*$/) { flush(); inblk = 1 }
      if (inblk) {
        buf[++nb] = line
        if (line ~ /reverse_proxy/) has_route = 1
        t = line; o = gsub(/\{/, "{", t); t = line; c = gsub(/\}/, "}", t)
        depth += o - c
        if (depth <= 0) { depth = 0; inblk = 0; flush() }
      } else {
        print line > out
      }
    }
    END { flush(); close(out) }
  ' "$conf"
  cat "$tmp_file" > "$conf"
  rm -f "$tmp_file"
}
