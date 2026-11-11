#!/bin/bash
# Prompt the user to configure containers individually or use shared settings.
_add_step_setup_mode() {
  while :; do
    echo "0) Back / Cancel"
    echo "1) Configure each VPS individually (Default)"
    echo "2) Same resource settings for all"
    read -r -p "Choice [0=Back, Enter=$(pref_get add_setup 1)]: " setup </dev/tty
    setup="${setup:-$(pref_get add_setup 1)}"
    if [ "$setup" = "0" ]; then
      return 1
    fi
    if ! [[ "$setup" =~ ^[12]$ ]]; then
      echo "Invalid choice."
      continue
    fi
    pref_set add_setup "$setup"
    return 0
  done
}
