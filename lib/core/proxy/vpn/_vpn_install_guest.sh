#!/bin/bash
# Run package, Xray and Hysteria2 binary installation inside a VPS container.
#   _vpn_install_guest <vps>
_vpn_install_guest() {
  local vps="${1:?vps}"
  incus exec "$vps" --env VER="$VPN_XRAY_VERSION" -- sh -c '
    set -e
    if command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get -o Acquire::ForceIPv4=true update
      apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends curl unzip ca-certificates qrencode openssl
    elif command -v apk >/dev/null 2>&1; then
      apk add --no-cache curl unzip ca-certificates libqrencode-tools openssl
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y curl unzip ca-certificates qrencode openssl
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
    if ! /usr/local/bin/hysteria version >/dev/null 2>&1; then
      case "$(uname -m)" in
        x86_64|amd64) h=amd64 ;;
        aarch64|arm64) h=arm64 ;;
        *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
      esac
      t=$(mktemp -d)
      curl -4 -fsSL -o "$t/hysteria" "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-$h"
      chmod +x "$t/hysteria"
      "$t/hysteria" version >/dev/null 2>&1 || { echo "Hysteria download is not a working binary."; rm -rf "$t"; exit 1; }
      install -m 755 "$t/hysteria" /usr/local/bin/hysteria
      rm -rf "$t"
    fi
    command -v qrencode >/dev/null && command -v openssl >/dev/null && /usr/local/bin/xray version >/dev/null && /usr/local/bin/hysteria version >/dev/null
  ' </dev/null
}
