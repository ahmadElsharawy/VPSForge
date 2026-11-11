#!/bin/bash
# Prompt the user for the number of VPS containers to add.
_add_step_count() {
  while :; do
    read -r -p "How many VPS containers do you want to add? [0=Cancel, Enter=$(pref_get add_count 1)]: " count </dev/tty
    count="${count:-$(pref_get add_count 1)}"
    if [ "$count" = "0" ]; then
      echo "Cancelled."
      return 1
    fi
    if ! [[ "$count" =~ ^[1-9][0-9]*$ ]]; then
      echo "Invalid count."
      continue
    fi
    pref_set add_count "$count"
    return 0
  done
}
