#!/bin/bash
# Toggles the auto start on login setting and updates autostart script.
_settings_toggle_auto_start() {
  if [ "${AUTO_START_ON_LOGIN:-off}" = "on" ]; then
    AUTO_START_ON_LOGIN="off"
    echo "Auto Start on Login: DISABLED"
  else
    AUTO_START_ON_LOGIN="on"
    echo "Auto Start on Login: ENABLED"
  fi
  save_settings
  sleep 1
}
