#!/bin/bash
# Ensure OpenSSH server is installed, configured for root login, and running in a guest VPS.
ensure_ssh_ready() {
  local name="$1"
  _configure_guest_sshd "$name" || return 1
  _wait_ssh_listening "$name"
}
