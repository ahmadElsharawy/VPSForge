#!/bin/bash
# Step B in wizard test that requests step back once before succeeding.
wz_b() { WZ_LOG+="b"; [ "${WZ_B_COUNT:-0}" -eq 0 ] && { WZ_B_COUNT=1; return "$WIZARD_BACK"; }; return 0; }
