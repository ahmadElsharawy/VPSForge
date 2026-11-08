#!/bin/bash
save_settings() {
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  {
    printf 'AUTO_REFRESH=%q\n' "$AUTO_REFRESH"
    printf 'REFRESH_INTERVAL=%q\n' "$REFRESH_INTERVAL"
    printf 'AUTO_START_ON_LOGIN=%q\n' "$AUTO_START_ON_LOGIN"
  } > "$SETTINGS_FILE"
  apply_autostart_login_config
}
