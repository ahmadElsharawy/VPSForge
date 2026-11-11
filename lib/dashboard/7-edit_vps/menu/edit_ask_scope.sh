#!/bin/bash
# Prompts whether to edit selected VPS instances individually or apply settings to all.
edit_ask_scope() {
  EDIT_SCOPE=1
  [ "${#SELECTED_VPS[@]}" -gt 1 ] || return 0
  local mode last
  last=$(pref_get edit_scope 1)
  echo "0) Back"
  echo "1) Configure each VPS individually (you answer once per VPS)$([ "$last" = "1" ] && echo '   <- last used')"
  echo "2) Same setting for all selected VPS$([ "$last" = "2" ] && echo '   <- last used')"
  read -r -p "Choice [0=Back, Enter=$last]: " mode
  mode="${mode:-$last}"
  [ "$mode" = "0" ] && return 1
  [[ "$mode" =~ ^[12]$ ]] || { echo "Invalid choice."; return 1; }
  EDIT_SCOPE="$mode"
  pref_set edit_scope "$mode"
  return 0
}
