#!/bin/bash
# Print ONE PowerShell block for Windows: SSH key, hidden auto-start tunnel, and a desktop icon that turns it on/off.
#   print_windows_tunnel_setup <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
print_windows_tunnel_setup() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}"
  local block

  # The words in @...@ are replaced below; the text is quoted so nothing is expanded by bash.
  block=$(cat <<'EOF'
& {
$id = '@ID@'
$k = "$env:USERPROFILE\.ssh\vpsforge_$id"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
if (-not (Test-Path $k)) {
  if ($PSVersionTable.PSVersion.Major -ge 7) { ssh-keygen -q -t ed25519 -N '' -f $k } else { ssh-keygen -q -t ed25519 -N '""' -f $k }
}
ssh -i $k -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p @SSHPORT@ @TARGET@ true 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Type the VPS password ONE time:"
  Get-Content "$k.pub" | ssh -o StrictHostKeyChecking=accept-new -p @SSHPORT@ @TARGET@ "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
  if ($LASTEXITCODE -ne 0) { throw "Could not copy the key (wrong password?). Nothing was started. Run it again." }
}
$r = "$env:USERPROFILE\.ssh\vpsforge_tunnel_$id.ps1"
Set-Content $r -Value 'while ($true) {', ('  ssh -N -i "' + $k + '" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@'), '  Start-Sleep 5', '}'
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$r`""
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "VPSForgeTunnel_$id" -Action $a -Trigger $t -Settings $s -Force | Out-Null
$g = "$env:USERPROFILE\.ssh\vpsforge_toggle_$id.ps1"
@'
$n = 'VPSForgeTunnel_@ID@'
if ((Get-ScheduledTask $n).State -eq 'Running') {
  Stop-ScheduledTask $n
  Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object { $_.CommandLine -like '*-R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  $m = 'Tunnel @TARGET@ port @TPORT@ is now OFF'
} else {
  Start-ScheduledTask $n
  $m = 'Tunnel @TARGET@ port @TPORT@ is now ON'
}
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show($m, 'VPSForge tunnel') | Out-Null
'@ | Set-Content $g
$w = New-Object -ComObject WScript.Shell
$l = $w.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Tunnel @HOST@ @TPORT@ on-off.lnk')
$l.TargetPath = 'powershell.exe'
$l.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$g`""
$l.IconLocation = 'shell32.dll,13'
$l.Save()
Start-ScheduledTask -TaskName "VPSForgeTunnel_$id"
Write-Host "Done. The tunnel is ON now and starts after every login. Use the desktop icon 'Tunnel @HOST@ @TPORT@ on-off' to turn it off or on."
}
EOF
)
  block="${block//@ID@/$(tunnel_windows_id "$host" "$sshport" "$tport")}"
  block="${block//@HOST@/$host}"
  block="${block//@TPORT@/$tport}"
  block="${block//@LPORT@/$lport}"
  block="${block//@SSHPORT@/$sshport}"
  block="${block//@TARGET@/${user}@${host}}"
  echo "$block"
}
