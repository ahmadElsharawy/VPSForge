#!/bin/bash
# Show what to run on YOUR computer to open the tunnel: one full Windows setup block, or a plain command.
#   print_tunnel_commands <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
print_tunnel_commands() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}"
  local id
  id=$(tunnel_windows_id "$host" "$sshport" "$tport")
  local base="ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"

  echo "WINDOWS - paste this whole block ONCE in PowerShell. It makes the key, asks the password one time,"
  echo "runs the tunnel hidden in the background (also after every login) and puts an on/off icon on your desktop."
  echo "Your site must run on port ${lport}:"
  echo
  print_windows_tunnel_setup "$user" "$host" "$sshport" "$tport" "$lport"
  echo
  echo "Remove it for good (PowerShell):"
  echo "   & { \$id = '${id}'; Stop-ScheduledTask VPSForgeTunnel_\$id; Get-CimInstance Win32_Process -Filter \"Name='ssh.exe'\" | Where-Object { \$_.CommandLine -like '*-R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }; Unregister-ScheduledTask VPSForgeTunnel_\$id -Confirm:\$false; Remove-Item \"\$env:USERPROFILE\.ssh\vpsforge_\$id*\", \"\$env:USERPROFILE\.ssh\vpsforge_tunnel_\$id.ps1\", \"\$env:USERPROFILE\.ssh\vpsforge_toggle_\$id.ps1\", ([Environment]::GetFolderPath('Desktop') + '\Tunnel ${host} ${tport} on-off.lnk') -ErrorAction SilentlyContinue }"
  echo
  echo "LINUX / macOS - keep it open and reconnect by itself:"
  echo "   while true; do ${base}; sleep 5; done"
  echo
  echo "Just one try, no setup (any system):"
  echo "   ${base}"
}
