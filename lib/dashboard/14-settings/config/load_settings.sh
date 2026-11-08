#!/bin/bash
load_settings() {
  if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck disable=SC1090
    source "$SETTINGS_FILE"
  fi
  [[ "$AUTO_REFRESH" = "on" || "$AUTO_REFRESH" = "off" ]] || AUTO_REFRESH="on"
  [[ "$REFRESH_INTERVAL" =~ ^[1-9][0-9]*$ ]] || REFRESH_INTERVAL=10
  [[ "${AUTO_START_ON_LOGIN:-off}" = "on" || "${AUTO_START_ON_LOGIN:-off}" = "off" ]] || AUTO_START_ON_LOGIN="off"
  apply_autostart_login_config
}
