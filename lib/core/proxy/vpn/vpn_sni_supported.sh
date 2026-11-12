#!/bin/bash
# True when <site> answers HTTPS with TLS 1.3 and HTTP/2: Reality only works with such a site.
#   vpn_sni_supported <site>
vpn_sni_supported() {
  local site="${1:?site}" version
  command -v curl >/dev/null 2>&1 || return 0   # cannot check here: let Xray try
  version=$(curl -s -o /dev/null -m 10 --tlsv1.3 --http2 -w '%{http_version}' "https://$site/" 2>/dev/null || true)
  [ "$version" = "2" ]
}
