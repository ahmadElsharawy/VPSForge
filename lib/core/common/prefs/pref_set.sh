#!/bin/bash
# Remember <value> as the new default answer for <key>.
#   pref_set <key> <value>
pref_set() {
  local key="${1:?key}" value="${2:-}"
  [[ "$key" =~ ^[a-z0-9_]+$ ]] || return 1
  [[ "$value" != *$'\n'* ]] || return 1
  mkdir -p "$(dirname "$PREFS_FILE")" 2>/dev/null || true
  touch "$PREFS_FILE" 2>/dev/null || return 0
  grep -v "^${key}=" "$PREFS_FILE" > "${PREFS_FILE}.tmp" 2>/dev/null || true
  echo "${key}=${value}" >> "${PREFS_FILE}.tmp"
  mv -f "${PREFS_FILE}.tmp" "$PREFS_FILE"
}
