#!/bin/bash
# Find out whether the app on <ip>:<port> speaks plain HTTP or HTTPS. Prints "http" or "https".
#   detect_backend_scheme <ip> <port>
detect_backend_scheme() {
  local ip="${1:?ip}" port="${2:?port}" code
  case "$port" in 443|8443) echo https; return 0;; esac

  code=$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://$ip:$port" 2>/dev/null)
  if [ -n "$code" ] && [ "$code" != "000" ]; then echo http; return 0; fi

  code=$(curl -sk -m 3 -o /dev/null -w '%{http_code}' "https://$ip:$port" 2>/dev/null)
  if [ -n "$code" ] && [ "$code" != "000" ]; then echo https; return 0; fi

  echo http
}
