#!/bin/bash
# Print the remembered answer for <key>, or <fallback> when there is none.
#   pref_get <key> <fallback>
pref_get() {
  local key="${1:?key}" fallback="${2:-}" value=""
  [ -f "$PREFS_FILE" ] && value=$(grep -m1 "^${key}=" "$PREFS_FILE" 2>/dev/null | cut -d= -f2-)
  if [ -n "$value" ]; then echo "$value"; else echo "$fallback"; fi
}
