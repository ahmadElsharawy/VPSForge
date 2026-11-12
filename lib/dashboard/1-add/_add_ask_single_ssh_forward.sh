#!/bin/bash
# Prompt for SSH port forwarding on an individual VPS container.
_add_ask_single_ssh_forward() {
  local container_name="$1" container_num="$2" assigned_port def_fwd
  assigned_port=$(vps_fixed_port "$container_num")
  def_fwd="${cur_ssh_fwd:-$(pref_get ssh_forward y)}"   # this VPS's earlier answer (after Back) wins
  echo "----------------------------------------------------------------"
  echo "SSH Port Forwarding for $container_name (Assigned Port: $assigned_port):"
  read -r -p "Forward external SSH Port ($PUBLIC_IP:$assigned_port -> 22)? [y/n, Enter=$def_fwd, 0=Back]: " cur_ssh_fwd </dev/tty
  if [ "$cur_ssh_fwd" = "0" ]; then
    return 1
  fi
  cur_ssh_fwd="${cur_ssh_fwd:-$def_fwd}"
  if [[ "${cur_ssh_fwd,,}" =~ ^n ]]; then
    cur_ssh_fwd="n"
  else
    cur_ssh_fwd="y"
  fi
  pref_set ssh_forward "$cur_ssh_fwd"
  return 0
}
