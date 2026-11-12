#!/bin/bash
# Ask whether a new VPS is Full (privileged: Docker works, only for trusted people) or Isolated
# (unprivileged: safe to rent to strangers, Docker does not work). The last answer is the default.
# Sets VPS_TYPE_RESULT to "full" or "isolated"; 0 returns 1 (back to the previous step).
#   ask_vps_type <target>
ask_vps_type() {
  local target="$1" def choice
  def=$(pref_get vps_type 1)
  [[ "$def" =~ ^[12]$ ]] || def=1
  echo "----------------------------------------------------------------"
  echo "VPS type for $target:"
  echo "0) Back"
  echo "1) Full            (privileged)    Docker works. Only for you or people you trust."
  echo "2) Isolated        (unprivileged)  Safe to rent to strangers. Docker does NOT work."
  while :; do
    read -r -p "Choice [0=Back, Enter=$def]: " choice </dev/tty
    choice="${choice:-$def}"
    case "$choice" in
      0) return 1 ;;
      1) VPS_TYPE_RESULT="full"; break ;;
      2) VPS_TYPE_RESULT="isolated"; break ;;
      *) echo "Choose 1 or 2." ;;
    esac
  done
  pref_set vps_type "$choice"
  return 0
}
