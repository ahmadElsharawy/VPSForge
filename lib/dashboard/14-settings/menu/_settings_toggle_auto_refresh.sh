#!/bin/bash
# Toggles the auto refresh configuration setting between on and off.
_settings_toggle_auto_refresh() {
  if [ "$AUTO_REFRESH" = "on" ]; then
    AUTO_REFRESH="off"
  else
    AUTO_REFRESH="on"
  fi
  save_settings
}
