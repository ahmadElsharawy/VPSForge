#!/bin/bash
# Install Xray (official release, checksum verified) and qrencode inside a VPS.
#   vpn_install_packages <vps>
vpn_install_packages() {
  local vps="${1:?vps}" attempt
  for attempt in 1 2 3; do
    if incus exec "$vps" --env VER="$VPN_XRAY_VERSION" -- sh -c '
      set -e
      if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get -o Acquire::ForceIPv4=true update
        apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends curl unzip ca-certificates qrencode
      elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl unzip ca-certificates libqrencode-tools
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl unzip ca-certificates qrencode
      else
        echo "Unsupported package manager."; exit 1
      fi
      if ! /usr/local/bin/xray version 2>/dev/null | grep -q "Xray ${VER#v} "; then
        case "$(uname -m)" in
          x86_64|amd64) a=64 ;;
          aarch64|arm64) a=arm64-v8a ;;
          *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
        esac
        t=$(mktemp -d)
        u="https://github.com/XTLS/Xray-core/releases/download/$VER/Xray-linux-$a.zip"
        curl -4 -fsSL -o "$t/x.zip" "$u"
        curl -4 -fsSL -o "$t/x.dgst" "$u.dgst"
        want=$(awk -F"= " "/SHA2-256|SHA256/ { print \$2; exit }" "$t/x.dgst")
        have=$(sha256sum "$t/x.zip" | cut -d" " -f1)
        [ -n "$want" ] && [ "$want" = "$have" ] || { echo "Xray download checksum mismatch."; rm -rf "$t"; exit 1; }
        unzip -o -q "$t/x.zip" xray -d "$t"
        install -m 755 "$t/xray" /usr/local/bin/xray
        rm -rf "$t"
      fi
      command -v qrencode >/dev/null && /usr/local/bin/xray version >/dev/null
    ' </dev/null; then
      return 0
    fi
    echo "Xray install attempt $attempt/3 failed for $vps. Retrying..."
    sleep 3
  done
  echo "ERROR: could not install Xray inside $vps."
  return 1
}
