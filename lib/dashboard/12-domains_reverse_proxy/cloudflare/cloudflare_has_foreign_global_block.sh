#!/bin/bash
# Succeeds when the Caddyfile (ignoring VPSForge's own block) already starts with a
# global options block "{ ... }". Two global blocks are not allowed, so we must not add ours.
#   cloudflare_has_foreign_global_block <caddyfile>
cloudflare_has_foreign_global_block() {
  local caddyfile="${1:?caddyfile}" first
  first=$(sed '/^# BEGIN VPSFORGE CLOUDFLARE$/,/^# END VPSFORGE CLOUDFLARE$/d' "$caddyfile" \
    | grep -vE '^[[:space:]]*(#.*)?$' | head -n 1)
  [[ "$first" =~ ^\{[[:space:]]*$ ]]
}
