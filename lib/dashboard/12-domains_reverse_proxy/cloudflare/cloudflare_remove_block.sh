#!/bin/bash
# Delete VPSForge's marked Cloudflare block from a Caddyfile, leaving everything else untouched.
#   cloudflare_remove_block <caddyfile>
cloudflare_remove_block() {
  local caddyfile="${1:?caddyfile}"
  sed -i '/^# BEGIN VPSFORGE CLOUDFLARE$/,/^# END VPSFORGE CLOUDFLARE$/d' "$caddyfile"
}
