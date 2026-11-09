#!/bin/bash
# Print every site address of a Caddy file read from stdin, one per line (every top-level block, not only the first).
#   caddy_site_domains < file
caddy_site_domains() {
  awk '
    {
      line = $0
      opens = gsub(/\{/, "{", line); closes = gsub(/\}/, "}", line)
      if (depth == 0 && $0 !~ /^[ \t]*#/ && $0 ~ /\{[ \t]*$/) {
        site = $0; sub(/\{[ \t]*$/, "", site); gsub(/,/, " ", site)
        n = split(site, parts, " ")
        for (i = 1; i <= n; i++) print parts[i]
      }
      depth += opens - closes
    }
  '
}
