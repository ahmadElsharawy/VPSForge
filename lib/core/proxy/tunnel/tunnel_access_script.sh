#!/bin/bash
# Print the PowerShell setup for Windows. The VPS keeps this text and hands it to the computer.
# It contains a key that can ONLY open one tunnel port, so it is safe to give to someone else.
#   tunnel_access_script <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port> <private_key_file>
tunnel_access_script() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" keyfile="${6:?key file}"
  local block key
  key=$(cat "$keyfile")

  # The words in @...@ are replaced below; the text is quoted so nothing is expanded by bash.
  block=$(cat <<'EOF2'
& {
$id = '@ID@'; $d = "$env:USERPROFILE\.ssh"; $k = "$d\vpsforge_$id"
New-Item -ItemType Directory -Force $d | Out-Null
$kt = @'
@KEY@
'@
Remove-Item $k -Force -ErrorAction SilentlyContinue
[IO.File]::WriteAllText($k, (($kt -replace "`r", "").Trim() + "`n"))
icacls $k /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
$r = "$d\vpsforge_tunnel_$id.ps1"
Set-Content $r -Value 'while ($true) {', ('  ssh -N -i "' + $k + '" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@'), '  Start-Sleep 5', '}'
$g = "$d\vpsforge_toggle_$id.ps1"
@'
$n = 'VPSForgeTunnel_@ID@'; if ((Get-ScheduledTask $n).State -eq 'Running') { Stop-ScheduledTask $n; Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object { $_.CommandLine -like '*-R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; $m = 'OFF' } else { Start-ScheduledTask $n; $m = 'ON' }; (New-Object -ComObject WScript.Shell).Popup("Tunnel @HOST@ port @TPORT@ is now $m", 3, 'VPSForge tunnel') | Out-Null
'@ | Set-Content $g
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$r`""
Register-ScheduledTask -TaskName "VPSForgeTunnel_$id" -Action $a -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)) -Force | Out-Null
$l = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Tunnel @HOST@ @TPORT@ on-off.lnk')
$l.TargetPath = 'powershell.exe'; $l.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$g`""; $l.IconLocation = 'shell32.dll,13'; $l.Save()
Start-ScheduledTask -TaskName "VPSForgeTunnel_$id"
Write-Host "Done. The tunnel is ON and starts after every login. Desktop icon: 'Tunnel @HOST@ @TPORT@ on-off'."
}
EOF2
)
  block="${block//@ID@/$(tunnel_windows_id "$host" "$sshport" "$tport")}"
  block="${block//@HOST@/$host}"
  block="${block//@TPORT@/$tport}"
  block="${block//@LPORT@/$lport}"
  block="${block//@SSHPORT@/$sshport}"
  block="${block//@TARGET@/${user}@${host}}"
  block="${block//@KEY@/$key}"
  echo "$block"
}
