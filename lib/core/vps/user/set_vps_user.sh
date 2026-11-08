#!/bin/bash
set_vps_user()     { incus config set "$1" user.vpsforge.username "$2" 2>/dev/null || true; }
