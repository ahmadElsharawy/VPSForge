#!/bin/bash
set_vps_password() { incus config set "$1" user.vpsforge.password "$2" 2>/dev/null || true; }
