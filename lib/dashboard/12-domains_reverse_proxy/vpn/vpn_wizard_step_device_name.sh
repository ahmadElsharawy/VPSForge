#!/bin/bash
# Add-device wizard step 1 of 2: the device name.
vpn_wizard_step_device_name() {
  local answer def
  echo "Step 1 of 2 - Device name"
  show_example "my-phone, laptop, home-pc  (letters, digits, - or _)"
  def=$(pref_get vpn_device_name my-phone)
  read -r -p "Device name [Enter=$def, 0=Back]: " answer </dev/tty
  [ "$answer" = "0" ] && return "$WIZARD_BACK"
  answer="${answer:-$def}"
  is_valid_vpn_device_name "$answer" || { echo "ERROR: use letters, digits, - or _ (max 32)."; return 1; }
  if vpn_list_devices "$VW_VPS" | awk -F'|' -v n="$answer" '$1 == n { f = 1 } END { exit !f }'; then
    echo "ERROR: a device named '$answer' already exists."; return 1
  fi
  VW_DEVICE="$answer"
  pref_set vpn_device_name "$answer"
  return 0
}
