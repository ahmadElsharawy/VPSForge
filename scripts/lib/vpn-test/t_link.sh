#!/bin/bash
# Verify format and parameters of the generated VLESS connection link.
t_link() { case "$LINK" in vless://*"@${PUBLIC_IP}:$PORT?"*"security=reality"*"pbk="*"sid="*"#${PUBLIC_IP}-${S}-unl-unl") return 0;; esac; return 1; }
