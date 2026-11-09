#!/bin/bash
# Remove ONE domain from a VPS's Caddy file, in every site block of the file.
# A block that has no domain left is removed whole; when no block is left, the file is deleted.
#   caddy_unlink_domain <caddy_file> <domain>
caddy_unlink_domain() {
  local file="${1:?caddy file}" domain="${2:?domain}" tmp rc
  [ -f "$file" ] || return 0
  tmp=$(mktemp)
  awk -v d="$domain" '
    function count(str, ch,   t) { t = str; return gsub(ch, "", t) }
    {
      opens = count($0, "{"); closes = count($0, "}")
      if (depth == 0 && /^[^ 	#].*\{[ 	]*$/) {
        line = $0; sub(/\{[ 	]*$/, "", line); gsub(/,/, " ", line)
        n = split(line, a, " "); out = ""
        for (i = 1; i <= n; i++) if (a[i] != d) out = out (out == "" ? "" : ", ") a[i]
        if (out == "") { skipping = 1 } else { print out " {"; kept++ }
        depth = opens - closes
        if (depth <= 0) { depth = 0; skipping = 0 }
        next
      }
      depth += opens - closes
      if (depth < 0) depth = 0
      if (!skipping) print
      if (depth == 0) skipping = 0
    }
    END { exit (kept > 0 ? 0 : 3) }
  ' "$file" > "$tmp"
  rc=$?
  if [ "$rc" -eq 3 ]; then rm -f "$file" "$tmp"; else mv -f "$tmp" "$file"; fi
  return 0
}
