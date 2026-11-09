#!/bin/bash
# Print the PowerShell line that removes ONE Windows tunnel setup (its task, its ssh, its own files and icon; other tunnels are not touched).
#   print_windows_tunnel_remove <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
print_windows_tunnel_remove() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" id
  id=$(tunnel_windows_id "$host" "$sshport" "$tport")
  echo "& { \$id = '${id}'; Stop-ScheduledTask VPSForgeTunnel_\$id; Get-CimInstance Win32_Process -Filter \"Name='ssh.exe'\" | Where-Object { \$_.CommandLine -like '*-R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }; Unregister-ScheduledTask VPSForgeTunnel_\$id -Confirm:\$false; icacls \"\$env:USERPROFILE\\.ssh\\vpsforge_\$id\" /grant:r \"\$(\$env:USERNAME):(F)\" | Out-Null; Remove-Item \"\$env:USERPROFILE\.ssh\vpsforge_\$id\", \"\$env:USERPROFILE\\.ssh\\vpsforge_\$id.pub\", \"\$env:USERPROFILE\.ssh\vpsforge_tunnel_\$id.ps1\", \"\$env:USERPROFILE\.ssh\vpsforge_toggle_\$id.ps1\", ([Environment]::GetFolderPath('Desktop') + '\Tunnel ${host} ${tport} on-off.lnk') -ErrorAction SilentlyContinue }"
}
