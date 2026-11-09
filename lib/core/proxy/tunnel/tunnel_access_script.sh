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
if (Test-Path $k) { icacls $k /grant:r "$($env:USERNAME):(F)" | Out-Null }
[IO.File]::WriteAllText($k, (($kt -replace "`r", "").Trim() + "`n"))
icacls $k /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
$r = "$d\vpsforge_tunnel_$id.ps1"
Set-Content $r -Value 'while ($true) {', ('  ssh -N -i "' + $k + '" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@'), '  Start-Sleep 5', '}'
$g = "$d\vpsforge_toggle_$id.ps1"
@'
Add-Type -AssemblyName System.Windows.Forms
$n = 'VPSForgeTunnel_@ID@'; $d = "$env:USERPROFILE\.ssh"; $id = '@ID@'
$lnk = [Environment]::GetFolderPath('Desktop') + '\Tunnel @HOST@ @TPORT@ on-off.lnk'
function Test-On { (Get-ScheduledTask $n -ErrorAction SilentlyContinue).State -eq 'Running' }
function Stop-Tunnel {
  Stop-ScheduledTask $n -ErrorAction SilentlyContinue
  Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" | Where-Object { $_.CommandLine -like '*-R 0.0.0.0:@TPORT@:localhost:@LPORT@ -p @SSHPORT@ @TARGET@*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}
$f = New-Object System.Windows.Forms.Form
$f.Text = 'VPSForge tunnel'; $f.ClientSize = New-Object System.Drawing.Size(340, 150); $f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
$t = New-Object System.Windows.Forms.Label; $t.Text = '@HOST@  port @TPORT@'; $t.Location = '15,12'; $t.Size = '310,20'; $f.Controls.Add($t)
$st = New-Object System.Windows.Forms.Label; $st.Location = '15,40'; $st.Size = '310,34'; $st.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold); $f.Controls.Add($st)
function Show-State { if (Test-On) { $st.Text = 'Tunnel is ON'; $st.ForeColor = 'DarkGreen' } else { $st.Text = 'Tunnel is OFF'; $st.ForeColor = 'Firebrick' } }
function New-Btn($text, $x) { $b = New-Object System.Windows.Forms.Button; $b.Text = $text; $b.Location = "$x,95"; $b.Size = '95,34'; $f.Controls.Add($b); $b }
$on = New-Btn 'On' 15; $off = New-Btn 'Off' 120; $del = New-Btn 'Delete' 225
$on.Add_Click({ Start-ScheduledTask $n; Start-Sleep 2; Show-State })
$off.Add_Click({ Stop-Tunnel; Start-Sleep 1; Show-State })
$del.Add_Click({
  $a = [System.Windows.Forms.MessageBox]::Show("Delete this tunnel from this computer?`nThe task, the key and this icon will be removed.", 'VPSForge tunnel', 'YesNo', 'Warning')
  if ($a -ne 'Yes') { return }
  Stop-Tunnel
  Unregister-ScheduledTask $n -Confirm:$false -ErrorAction SilentlyContinue
  $k = "$d\vpsforge_$id"
  if (Test-Path $k) { icacls $k /grant:r "$($env:USERNAME):(F)" | Out-Null }
  Remove-Item $k, "$k.pub", "$d\vpsforge_tunnel_$id.ps1", $lnk -Force -ErrorAction SilentlyContinue
  $f.Tag = 'deleted'; $f.Close()
})
$timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 3000; $timer.Add_Tick({ Show-State }); $timer.Start()
Show-State
[void]$f.ShowDialog()
if ($f.Tag -eq 'deleted') { Remove-Item "$d\vpsforge_toggle_$id.ps1" -Force -ErrorAction SilentlyContinue }
'@ | Set-Content $g
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$r`""
Register-ScheduledTask -TaskName "VPSForgeTunnel_$id" -Action $a -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)) -Force | Out-Null
$l = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Tunnel @HOST@ @TPORT@ on-off.lnk')
$l.TargetPath = 'powershell.exe'; $l.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$g`""; $l.IconLocation = 'shell32.dll,13'; $l.Save()
Start-ScheduledTask -TaskName "VPSForgeTunnel_$id"
Write-Host "Done. The tunnel is ON and starts after every login. Desktop icon: 'Tunnel @HOST@ @TPORT@ on-off' (On / Off / Delete)."
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
