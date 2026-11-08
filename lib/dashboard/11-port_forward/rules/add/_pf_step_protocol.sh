#!/bin/bash
# Port-forward wizard step 4 of 5: TCP, UDP or both (defaults to your last choice).
_pf_step_protocol() {
  local choice last
  last=$(pref_get pf_protocol 1)
  echo
  echo "Step 4 of 5 - Protocol"
  echo "  1) TCP$([ "$last" = "1" ] && echo '   <- last used')"
  echo "  2) UDP$([ "$last" = "2" ] && echo '   <- last used')"
  echo "  3) BOTH (TCP + UDP)$([ "$last" = "3" ] && echo '   <- last used')"
  read -r -p "Choice [1-3, Enter=$last, 0=Back]: " choice </dev/tty
  choice="${choice:-$last}"
  case "$choice" in
    0) return "$WIZARD_BACK";;
    2) PF_PROTOCOL="udp";;
    3) PF_PROTOCOL="both";;
    *) PF_PROTOCOL="tcp"; choice=1;;
  esac
  pref_set pf_protocol "$choice"
  return 0
}
