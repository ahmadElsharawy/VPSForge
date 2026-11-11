#!/bin/bash
# Make (or refresh) the limited login of one tunnel port inside the VPS and store the setup script there.
# The login can only open that one port: no shell, no other forwards, no unix sockets. The key is kept, so
# setups already installed on computers keep working; only the password to download the script is renewed.
# With "renew" a NEW key is made, so every setup installed before stops working.
# Sets TUNNEL_ACCESS_USER and TUNNEL_ACCESS_PASS.
#   tunnel_access_prepare <vps> <server_ip> <ssh_port> <tunnel_port> <local_port> [renew]
tunnel_access_prepare() {
  local vps="${1:?vps}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" renew="${6:-}"
  local user dir pub rc

  user=$(tunnel_access_user "$tport")
  dir=$(mktemp -d)

  # Keep the existing key unless a new one was asked for.
  [ "$renew" = "renew" ] || incus exec "$vps" --env TPORT="$tport" -- sh -c 'cat "/etc/vpsforge-tunnel/$TPORT.key"' </dev/null > "$dir/k" 2>/dev/null || true
  if [ ! -s "$dir/k" ]; then
    rm -f "$dir/k"
    ssh-keygen -q -t ed25519 -N '' -C "vpsforge-tunnel-$tport" -f "$dir/k" || { rm -rf "$dir"; return 1; }
  fi
  chmod 600 "$dir/k"
  pub=$(ssh-keygen -y -f "$dir/k")
  TUNNEL_ACCESS_USER="$user"
  TUNNEL_ACCESS_PASS=$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')

  # 1) the login itself (the password goes in through stdin, never on a command line)
  printf '%s:%s\n' "$user" "$TUNNEL_ACCESS_PASS" | incus exec "$vps" --env TUSER="$user" --env TPORT="$tport" --env TPUB="$pub" -- sh -c '
    mkdir -p /etc/vpsforge-tunnel && chmod 755 /etc/vpsforge-tunnel || exit 1
    sh_file="/etc/vpsforge-tunnel/$TPORT.sh"
    printf "#!/bin/sh\ncat /etc/vpsforge-tunnel/%s.ps1\n" "$TPORT" > "$sh_file" && chmod 755 "$sh_file"
    id "$TUSER" >/dev/null 2>&1 || useradd -m -s "$sh_file" "$TUSER" || exit 1
    chpasswd || exit 1
    install -d -m 700 -o "$TUSER" -g "$TUSER" "/home/$TUSER/.ssh"
    printf "restrict,port-forwarding,permitlisten=\"0.0.0.0:%s\",permitopen=\"127.0.0.1:1\",command=\"/bin/false\" %s\n" "$TPORT" "$TPUB" > "/home/$TUSER/.ssh/authorized_keys"
    chown "$TUSER:$TUSER" "/home/$TUSER/.ssh/authorized_keys"; chmod 600 "/home/$TUSER/.ssh/authorized_keys"
  ' >/dev/null 2>&1 || { rm -rf "$dir"; return 1; }

  # 2) the key and the setup script (readable only by root and by this login)
  incus exec "$vps" --env TPORT="$tport" --env TUSER="$user" -- sh -c 'cat > "/etc/vpsforge-tunnel/$TPORT.key" && chmod 600 "/etc/vpsforge-tunnel/$TPORT.key"' < "$dir/k" 2>/dev/null || { rm -rf "$dir"; return 1; }
  tunnel_access_script "$user" "$host" "$sshport" "$tport" "$lport" "$dir/k" > "$dir/script.ps1"
  incus exec "$vps" --env TPORT="$tport" --env TUSER="$user" -- sh -c 'f="/etc/vpsforge-tunnel/$TPORT.ps1"; cat > "$f" && chown "root:$TUSER" "$f" && chmod 640 "$f"' < "$dir/script.ps1" 2>/dev/null || { rm -rf "$dir"; return 1; }

  # 3) the ssh rules. If they are not accepted, the whole login is removed again (never leave a half-limited one).
  _tunnel_access_configure_sshd "$vps" "$user" "$tport"
  rc=$?
  rm -rf "$dir"
  return "$rc"
}
