#!/bin/bash
# Remove ONE domain from a VPS's Caddy file: if the site block lists several domains,
# only the named one is cut out; if it was alone, the whole block is deleted.
#   caddy_unlink_domain <caddy_file> <domain>
caddy_unlink_domain() {
  local conf="${1:?caddy file}" domain="${2:?domain}" tmp_file
  [ -f "$conf" ] || return 0
  tmp_file=$(mktemp) || return 1
  awk -v d="$domain" -v out="$tmp_file" '
    function drop_domain(header, target,   arr, n, i, out_h) {
      gsub(/[[:space:]]*\{.*/, "", header)
      n = split(header, arr, /[[:space:]]*,[[:space:]]*/)
      out_h = ""
      for (i = 1; i <= n; i++) {
        if (arr[i] != target && arr[i] != "") out_h = (out_h == "" ? arr[i] : out_h ", " arr[i])
      }
      return out_h
    }
    {
      line = $0
      if (depth == 0 && line ~ /^[^[:space:]#].*\{[[:space:]]*$/) {
        if (line ~ ("(^|[[:space:],])" d "([[:space:],{]|$)")) {
          new_h = drop_domain(line, d)
          if (new_h == "") { drop_block = 1 }
          else { line = new_h " {" }
        }
      }
      if (drop_block) {
        t = line; o = gsub(/\{/, "{", t); t = line; c = gsub(/\}/, "}", t)
        depth += o - c
        if (depth <= 0) { depth = 0; drop_block = 0 }
        next
      }
      print line > out
    }
  ' "$conf"
  cat "$tmp_file" > "$conf"
  rm -f "$tmp_file"

  # If the file has no real content left, delete it so Caddy never imports an empty file.
  if ! grep -qE '^[^[:space:]#]' "$conf" 2>/dev/null; then
    rm -f "$conf"
  fi
}
