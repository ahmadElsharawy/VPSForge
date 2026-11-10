#!/bin/bash
# Add-device wizard step 3 of 2: data limit (GB) and number of days. 0 = unlimited for either.
# The device is switched off by itself when one of them runs out.
vpn_wizard_step_device_limits() {
  local answer gb days
  gb=$(pref_get vpn_device_gb 0)
  days=$(pref_get vpn_device_days 0)
  echo
  echo "Step 2 of 2 - Limits (0 = unlimited)"
  show_example "50 GB for 30 days   or   0 and 0 for no limits at all"
  read -r -p "Data limit in GB [Enter=$gb, 0=unlimited, B=Back]: " answer </dev/tty
  [[ "${answer,,}" = "b" ]] && return "$WIZARD_BACK"
  answer="${answer:-$gb}"
  [[ "$answer" =~ ^[0-9]+$ ]] || { echo "ERROR: type a whole number of GB (0 = unlimited)."; return 1; }
  VW_GB="$answer"
  read -r -p "Number of days [Enter=$days, 0=unlimited, B=Back]: " answer </dev/tty
  [[ "${answer,,}" = "b" ]] && return "$WIZARD_BACK"
  answer="${answer:-$days}"
  [[ "$answer" =~ ^[0-9]+$ ]] || { echo "ERROR: type a whole number of days (0 = unlimited)."; return 1; }
  VW_DAYS="$answer"
  pref_set vpn_device_gb "$VW_GB"; pref_set vpn_device_days "$VW_DAYS"
  return 0
}
