#!/bin/bash
# Verify that the temporary QR code web page returns the base64 image.
t_page() { curl -fsS -m 5 "http://127.0.0.1:$P2$path" | grep -q 'data:image/png;base64'; }
