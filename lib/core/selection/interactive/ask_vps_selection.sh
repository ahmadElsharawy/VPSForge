#!/bin/bash
# Pick one, several or all VPSs. Enter repeats your last choice (when those VPSs still exist).
#   ask_vps_selection [prompt] [single]
# "single": for menus that work on ONE VPS, Enter repeats the single VPS you used last.
ask_vps_selection() {
  local prompt_text="${1:-Select VPS by number, name, or A for All [0=Back, Enter=1]: }" mode="${2:-multi}"
  local raw default last name ok=1
  list_available_vps || return 1

  if [ "$mode" = "single" ]; then last=$(pref_get last_vps ""); else last=$(pref_get last_selection ""); fi
  default=1
  if [ -n "$last" ]; then
    for name in ${last//,/ }; do incus info "$name" >/dev/null 2>&1 || ok=0; done
    [ "$ok" -eq 1 ] && default="$last"
  fi
  prompt_text="${prompt_text//Enter=1/Enter=$default}"

  show_example "1 (one VPS)   1,3 (several)   1-3 (a range)   web1 (by name)   A (all)"
  read -r -p "$prompt_text" raw </dev/tty
  raw="${raw:-$default}"
  if [ "$raw" = "0" ]; then
    echo "Cancelled."
    return 1
  fi
  normalize_selection "$raw" || return 1
  pref_set last_selection "$(IFS=,; echo "${SELECTED_VPS[*]}")"
  [ "${#SELECTED_VPS[@]}" -eq 1 ] && pref_set last_vps "${SELECTED_VPS[0]}"
  return 0
}
