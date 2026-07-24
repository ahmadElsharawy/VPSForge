#!/bin/bash
# VPSForge — Settings, auto-refresh, and version management.

# ── Settings State ───────────────────────────────────────────────────────────

SETTINGS_FILE="/opt/vpsforge/settings.conf"
AUTO_REFRESH="on"
REFRESH_INTERVAL=10

# ── Load / Save ──────────────────────────────────────────────────────────────

load_settings() {
  if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE"
  fi
  [[ "$AUTO_REFRESH" = "on" || "$AUTO_REFRESH" = "off" ]] || AUTO_REFRESH="on"
  [[ "$REFRESH_INTERVAL" =~ ^[1-9][0-9]*$ ]] || REFRESH_INTERVAL=10
}

save_settings() {
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  {
    printf 'AUTO_REFRESH=%q\n' "$AUTO_REFRESH"
    printf 'REFRESH_INTERVAL=%q\n' "$REFRESH_INTERVAL"
  } > "$SETTINGS_FILE"
}

# ── Version Utilities ────────────────────────────────────────────────────────

extract_version_from_text() {
  tr -d '\r' | grep -oE 'v[0-9]+(\.[0-9]+)*' | head -n1 || true
}

verify_installed_version() {
  local app="$1" target="$2" installed="" attempt

  for attempt in $(seq 1 10); do
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ "$installed" = "$target" ] && return 0
    sleep 1
  done

  # Fallback: read the version constant directly from the installed file.
  installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
  [ "$installed" = "$target" ]
}

# ── Update Menu ──────────────────────────────────────────────────────────────

update_menu() {
  local repo="/opt/vpsforge/repo"
  local app="/opt/vpsforge/vpsforge.sh"
  local choice target backup installed i
  local -a tags

  echo "Current version: $VPSFORGE_VERSION"
  [ -d "$repo/.git" ] || { echo "No Git repository configured."; pause; return; }

  echo "Checking available versions..."
  git -C "$repo" fetch --tags --force --prune --prune-tags || { echo "Failed to fetch versions."; pause; return; }
  mapfile -t tags < <(git -C "$repo" tag --sort=-version:refname)
  [ "${#tags[@]}" -gt 0 ] || { echo "No tagged versions found."; pause; return; }

  echo "Available versions:"
  for i in "${!tags[@]}"; do
    if [ "${tags[$i]}" = "$VPSFORGE_VERSION" ]; then
      echo "$((i+1))) ${tags[$i]} (current)"
    else
      echo "$((i+1))) ${tags[$i]}"
    fi
  done

  read -r -p "Choose version number, or press Enter to cancel: " choice
  [ -n "$choice" ] || return
  [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tags[@]}" ] || {
    echo "Invalid choice."; pause; return
  }

  target="${tags[$((choice-1))]}"
  [ "$target" != "$VPSFORGE_VERSION" ] || { echo "Already running $target."; pause; return; }

  backup="/opt/vpsforge/vpsforge.sh.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$app" "$backup" || { echo "Failed to create backup."; pause; return; }

  echo "Switching: $VPSFORGE_VERSION -> $target"
  if ! git -C "$repo" show "${target}:vpsforge.sh" > "${app}.new"; then
    echo "Failed to read vpsforge.sh from tag $target."
    rm -f "${app}.new"
    pause
    return
  fi

  # Backup current lib directory if present
  if [ -d "/opt/vpsforge/lib" ]; then
    rm -rf "/opt/vpsforge/lib.backup"
    cp -r "/opt/vpsforge/lib" "/opt/vpsforge/lib.backup" 2>/dev/null || true
  fi

  # Extract lib/ directory from target version if present
  if git -C "$repo" archive "$target" lib 2>/dev/null | tar -x -C "/opt/vpsforge" 2>/dev/null; then
    chmod +x /opt/vpsforge/lib/*.sh 2>/dev/null || true
  fi

  if grep -Eq '^VPSFORGE_VERSION=' "${app}.new"; then
    sed -i -E 's/^VPSFORGE_VERSION="v[0-9]+(\.[0-9]+)*"/VPSFORGE_VERSION="'"${target}"'"/' "${app}.new"
  fi

  chmod 755 "${app}.new"
  mv -f "${app}.new" "$app"

  if ! verify_installed_version "$app" "$target"; then
    installed=$("$app" --version 2>/dev/null | extract_version_from_text)
    [ -n "$installed" ] || installed=$(sed -n 's/^VPSFORGE_VERSION="\(v[0-9][0-9.]*\)"/\1/p' "$app" 2>/dev/null | head -n1)
    echo "Verification failed. Expected: $target | Installed: ${installed:-unknown}"
    echo "Restoring previous version..."
    cp "$backup" "$app"
    chmod 755 "$app"
    echo "Rollback completed."
    pause
    return 1
  fi

  installed=$target
  echo "Success: $VPSFORGE_VERSION -> $installed"
  sleep 1
  exec "$app"
}

# ── Settings Menu ────────────────────────────────────────────────────────────

settings_menu() {
  local c new_interval
  while :; do
    clear
    echo "================================================"
    echo "                    SETTINGS"
    echo "================================================"
    echo
    echo "Auto Refresh: $([ "$AUTO_REFRESH" = "on" ] && echo ON || echo OFF)"
    echo "Refresh Interval: ${REFRESH_INTERVAL} seconds"
    echo "Current Version: $VPSFORGE_VERSION"
    echo
    echo "0) Back"
    echo "1) Enable / Disable Auto Refresh"
    echo "2) Change Refresh Interval"
    echo "3) Repair Connection"
    echo "4) Update / Change Version"
    echo
    read -r -p "Choice: " c

    case "$c" in
      1)
        if [ "$AUTO_REFRESH" = "on" ]; then AUTO_REFRESH="off"; else AUTO_REFRESH="on"; fi
        save_settings
        ;;
      2)
        read -r -p "New refresh interval in seconds: " new_interval
        [[ "$new_interval" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid interval."; pause; continue; }
        REFRESH_INTERVAL="$new_interval"
        save_settings
        ;;
      3) repair_connection_menu; pause;;
      4) update_menu;;
      0) return;;
      *) sleep 1;;
    esac
  done
}
