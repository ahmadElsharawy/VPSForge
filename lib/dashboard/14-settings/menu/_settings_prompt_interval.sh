#!/bin/bash
# Prompts the user for a new refresh interval and persists the setting.
_settings_prompt_interval() {
  local new_interval
  show_example "10  (the dashboard refreshes every 10 seconds)"
  read -r -p "Enter new refresh interval in seconds (min 2s) [Enter = $REFRESH_INTERVAL, 0=Back]: " new_interval
  [ "$new_interval" = "0" ] && return
  new_interval="${new_interval:-$REFRESH_INTERVAL}"
  if [[ "$new_interval" =~ ^[0-9]+$ ]] && [ "$new_interval" -ge 2 ]; then
    REFRESH_INTERVAL="$new_interval"
    save_settings
  else
    echo "Invalid interval. Must be a number >= 2."
    sleep 2
  fi
}
