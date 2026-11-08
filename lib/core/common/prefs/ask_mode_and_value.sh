#!/bin/bash
# One shared question for every resource (RAM, CPU, disk, network speed):
# "1) Unlimited  2) Set a limit". Both the mode and the number default to what
# you chose last time, so pressing Enter repeats it. Sets <PREFIX>_MODE_RESULT /
# <PREFIX>_VALUE_RESULT. Returns 1 for Back.
#   ask_mode_and_value <target> <pref_key> <PREFIX> <title> <unit> <limit_prompt_hint> <validator_fn> [error_text]
# validator_fn <value> <target> succeeds when the value is acceptable.
ask_mode_and_value() {
  local target="$1" key="$2" prefix="$3" title="$4" unit="$5" hint="$6" validator="$7"
  local error_text="${8:-Invalid value.}" choice value last_mode last_value
  last_mode=$(pref_get "${key}_mode" 1)
  last_value=$(pref_get "${key}_value" "")

  while :; do
    echo "----------------------------------------------------------------"
    echo "$title Mode for $target:"
    echo "0) Back"
    echo "1) Unlimited$([ "$last_mode" = "1" ] && echo '   <- last used')"
    echo "2) Set a limit${last_value:+ (last: ${last_value}${unit})}$([ "$last_mode" = "2" ] && echo '   <- last used')"
    read -r -p "Choice [0=Back, Enter=$last_mode]: " choice
    choice="${choice:-$last_mode}"
    case "$choice" in
      0) return 1;;
      1)
        printf -v "${prefix}_MODE_RESULT" '%s' "unlimited"
        printf -v "${prefix}_VALUE_RESULT" '%s' ""
        pref_set "${key}_mode" 1
        return 0
        ;;
      2)
        while :; do
          read -r -p "$title limit ($hint, or 0 to back)${last_value:+ [Enter=${last_value}]}: " value
          [ "${value:-}" = "0" ] && continue 2
          value="${value:-$last_value}"
          if [ -n "$value" ] && "$validator" "$value" "$target"; then
            printf -v "${prefix}_MODE_RESULT" '%s' "limited"
            printf -v "${prefix}_VALUE_RESULT" '%s' "$value"
            pref_set "${key}_mode" 2
            pref_set "${key}_value" "$value"
            return 0
          fi
          echo "$error_text"
        done
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
