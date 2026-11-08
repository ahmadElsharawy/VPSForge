#!/bin/bash
# Fast path: the full host setup (package checks, storage migration, sysctls,
# kernel modules...) only runs when the version changed, the stamp is older
# than a day, or "force" is passed (vpsforge setup). Normal launches skip it.
ensure_setup() {
  local force="${1:-}" stamp="${VPSFORGE_VERSION:-unknown}:$(get_active_installed_commit 2>/dev/null)"
  local now mtime
  now=$(date +%s)

  if [ "$force" != "force" ] && [ -f "$SETUP_STAMP_FILE" ] \
     && command -v incus >/dev/null 2>&1 \
     && incus network show incusbr0 >/dev/null 2>&1 \
     && [ "$(cat "$SETUP_STAMP_FILE" 2>/dev/null)" = "$stamp" ]; then
    mtime=$(stat -c %Y "$SETUP_STAMP_FILE" 2>/dev/null || echo 0)
    [ $((now - mtime)) -lt "$SETUP_STAMP_TTL" ] && return 0
  fi

  ensure_setup_full || return 1
  mkdir -p "$(dirname "$SETUP_STAMP_FILE")" 2>/dev/null || true
  printf '%s' "$stamp" > "$SETUP_STAMP_FILE" 2>/dev/null || true
}
