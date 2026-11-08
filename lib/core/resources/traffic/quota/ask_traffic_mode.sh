#!/bin/bash
# Ask: unlimited traffic or a download/upload quota in GB (defaults to your last answer).
# Sets TRAFFIC_MODE_RESULT / TRAFFIC_RX_RESULT / TRAFFIC_TX_RESULT. Returns 1 for Back.
ask_traffic_mode() {
  local target="$1" choice rx tx last_mode last_rx last_tx
  last_mode=$(pref_get traffic_mode 1)
  last_rx=$(pref_get traffic_rx 0)
  last_tx=$(pref_get traffic_tx 0)
  while :; do
    echo "----------------------------------------------------------------"
    echo "Traffic Data Limit (Download / Upload Quota) for $target:"
    echo "0) Back"
    echo "1) Unlimited Traffic Data$([ "$last_mode" = "1" ] && echo '   <- last used')"
    echo "2) Set Custom Data Quota (Download & Upload in GB) (last: ${last_rx}/${last_tx})$([ "$last_mode" = "2" ] && echo '   <- last used')"
    read -r -p "Choice [0=Back, Enter=$last_mode]: " choice </dev/tty
    choice="${choice:-$last_mode}"
    case "$choice" in
      0) return 1;;
      1)
        TRAFFIC_MODE_RESULT="unlimited"; TRAFFIC_RX_RESULT=0; TRAFFIC_TX_RESULT=0
        pref_set traffic_mode 1
        return 0
        ;;
      2)
        read -r -p "Download (Rx) Data Limit in GB [0=Unlimited, Enter=$last_rx]: " rx </dev/tty
        rx="${rx:-$last_rx}"; [[ "$rx" =~ ^[0-9]+$ ]] || rx=0
        read -r -p "Upload (Tx) Data Limit in GB [0=Unlimited, Enter=$last_tx]: " tx </dev/tty
        tx="${tx:-$last_tx}"; [[ "$tx" =~ ^[0-9]+$ ]] || tx=0
        TRAFFIC_MODE_RESULT="limited"; TRAFFIC_RX_RESULT="$rx"; TRAFFIC_TX_RESULT="$tx"
        pref_set traffic_mode 2; pref_set traffic_rx "$rx"; pref_set traffic_tx "$tx"
        return 0
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
