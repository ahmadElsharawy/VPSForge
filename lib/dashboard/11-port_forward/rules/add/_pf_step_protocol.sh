#!/bin/bash
# Port-forward wizard step 4 of 5: TCP, UDP or both (defaults to your last choice).
_pf_step_protocol() {
  local choice last
  last=$(pref_get pf_protocol 1)
  echo
  echo "Step 4 of 5 - Protocol"
  show_example "TCP for websites, SSH and most apps; UDP for games, VPN and DNS"
  echo "  1) TCP$([ "$last" = "1" ] && echo '   <- last used')"
  echo "  2) UDP$([ "$last" = "2" ] && echo '   <- last used')"
  echo "  3) BOTH (TCP + UDP)$([ "$last" = "3" ] && echo '   <- last used')"
  while :; do
    read -r -p "Choice [1-3, Enter=$last, 0=Back]: " choice </dev/tty
    choice="${choice:-$last}"
    case "$choice" in
      0) return "$WIZARD_BACK";;
      1) PF_PROTOCOL="tcp"; break;;
      2) PF_PROTOCOL="udp"; break;;
      3) PF_PROTOCOL="both"; break;;
      *) echo "Invalid choice. Please enter 1, 2, or 3.";;
    esac
  done
  pref_set pf_protocol "$choice"
  return 0
}
