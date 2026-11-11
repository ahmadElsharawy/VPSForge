#!/bin/bash
# Prompt the user for shared SSH port forwarding preference.
_add_ask_shared_ssh_forward() {
  echo "----------------------------------------------------------------"
  echo "SSH Port Forwarding for all new containers:"
  read -r -p "Forward external SSH Port (Port -> 22) for all VPS? [y/n, Enter=$(pref_get ssh_forward y), 0=Back]: " shared_ssh_fwd </dev/tty
  if [ "$shared_ssh_fwd" = "0" ]; then
    return 1
  fi
  shared_ssh_fwd="${shared_ssh_fwd:-$(pref_get ssh_forward y)}"
  if [[ "${shared_ssh_fwd,,}" =~ ^n ]]; then
    shared_ssh_fwd="n"
  else
    shared_ssh_fwd="y"
  fi
  pref_set ssh_forward "$shared_ssh_fwd"
  return 0
}
