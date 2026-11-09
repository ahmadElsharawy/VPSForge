#!/bin/bash
# Remove ONE domain from a VPS's Caddy file (the other domains of that VPS stay).
# When no domain is left in the file, the file is deleted.
#   caddy_unlink_domain <caddy_file> <domain>
caddy_unlink_domain() {
  local file="${1:?caddy file}" domain="${2:?domain}" tmp rc
  [ -f "$file" ] || return 0
  tmp=$(mktemp)
  awk -v d="$domain" '
    !done && /^[^ \t#].*\{[ \t]*$/ {
      line = $0; sub(/\{[ \t]*$/, "", line); gsub(/,/, " ", line)
      n = split(line, a, " "); out = ""
      for (i = 1; i <= n; i++) if (a[i] != d) out = out (out == "" ? "" : ", ") a[i]
      done = 1
      if (out == "") { empty = 1 } else { print out " {" }
      next
    }
    { print }
    END { exit (empty ? 3 : 0) }
  ' "$file" > "$tmp"
  rc=$?
  if [ "$rc" -eq 3 ]; then rm -f "$file" "$tmp"; else mv -f "$tmp" "$file"; fi
  return 0
}
