#!/bin/bash
# Updates username or password for selected VPS instances individually or in bulk.
edit_text_for_selection() {
  local what="${1:?username|password}" value="" n first=1 silent="" last=""
  [ "$what" = "username" ] && last=$(pref_get edit_username "")
  [ "$what" = "password" ] && silent="-s"
  edit_ask_scope || return

  if [ "$what" = "username" ]; then show_example "admin  (a new login name with full sudo rights)"; else show_example "a long password, for example MyStr0ng-Pass  (not shown while typing)"; fi
  for n in "${SELECTED_VPS[@]}"; do
    if [ "$EDIT_SCOPE" = "2" ] && [ "$first" -eq 0 ]; then
      :  # same value as the first VPS
    elif [ "${#SELECTED_VPS[@]}" -gt 1 ] && [ "$EDIT_SCOPE" = "2" ]; then
      read -r $silent -p "New $what for all${last:+ [Enter=$last]} [0=Back]: " value
      value="${value:-$last}"
      [ -z "$silent" ] || echo
      { [ "$value" = "0" ] || [ -z "$value" ]; } && return
    else
      [ "${#SELECTED_VPS[@]}" -gt 1 ] && echo "--- $n ---"
      read -r $silent -p "New $what${last:+ [Enter=$last]} [0=Back]: " value
      value="${value:-$last}"
      [ -z "$silent" ] || echo
      { [ "$value" = "0" ] || [ -z "$value" ]; } && continue
    fi
    first=0
    if [ "$what" = "password" ]; then
      change_vps_password "$n" "$value"
    else
      change_vps_username "$n" "$value" && pref_set edit_username "$value"
    fi
  done
}
