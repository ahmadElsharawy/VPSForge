#!/bin/bash
# Verify that invalid Caddy configuration changes are rolled back automatically.
rollback_works() {
  local b="$conf.bak"; cp "$conf" "$b"; echo "bogus {{{" >> "$conf"
  if caddy_apply_or_rollback "$conf" "$b"; then return 1; fi
  ! grep -q bogus "$conf" && caddy_valid
}
