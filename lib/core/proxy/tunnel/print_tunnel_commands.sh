#!/bin/bash
# Show what to run on YOUR computer to open the tunnel: one full Windows setup block (key + hidden auto-start), or a plain command.
#   print_tunnel_commands <ssh_user> <server_ip> <ssh_port> <tunnel_port> <local_port>
print_tunnel_commands() {
  local user="${1:?user}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}"
  local base="ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:${tport}:localhost:${lport} -p ${sshport} ${user}@${host}"
  local block

  # The Windows block. The words in @...@ are replaced below; it uses only quoted text so nothing is expanded here.
  block=$(cat <<'EOF'
$k = "$env:USERPROFILE\.ssh\vpsforge_@TPORT@"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
if (-not (Test-Path $k)) {
  ssh-keygen -q -t ed25519 -N '""' -f $k
  Write-Host "Type the VPS password ONE time:"
  Get-Content "$k.pub" | ssh -o StrictHostKeyChecking=accept-new -p @SSHPORT@ @TARGET@ "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
  if ($LASTEXITCODE -ne 0) { Remove-Item "$k","$k.pub" -Force; throw "Could not copy the key (wrong password?). Run it again." }
}
$r = "$env:USERPROFILE\.ssh\vpsforge_tunnel_@TPORT@.ps1"
Set-Content $r -Value 'while ($true) {', ('  ssh -N -i "' + $k + '" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@'), '  Start-Sleep 5', '}'
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$r`""
$t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "VPSForgeTunnel_@TPORT@" -Action $a -Trigger $t -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName "VPSForgeTunnel_@TPORT@"
Write-Host "Done. The tunnel runs hidden now and after every Windows login."
EOF
)
  block="${block//@TPORT@/$tport}"
  block="${block//@LPORT@/$lport}"
  block="${block//@SSHPORT@/$sshport}"
  block="${block//@TARGET@/${user}@${host}}"

  echo "WINDOWS - paste this whole block ONCE in PowerShell. It makes the key, asks the password one time,"
  echo "then runs the tunnel hidden in the background, and again after every login (your site must run on port ${lport}):"
  echo
  echo "$block"
  echo
  echo "To stop it later (PowerShell):  Stop-ScheduledTask VPSForgeTunnel_${tport}; Get-Process ssh | Stop-Process"
  echo "To remove it for good:          Unregister-ScheduledTask VPSForgeTunnel_${tport} -Confirm:\$false"
  echo
  echo "LINUX / macOS - keep it open and reconnect by itself:"
  echo "   while true; do ${base}; sleep 5; done"
  echo
  echo "Just one try, no setup (any system):"
  echo "   ${base}"
}
