#!/bin/bash
get_vps_user()     { incus config get "$1" user.vpsforge.username 2>/dev/null || echo root; }
