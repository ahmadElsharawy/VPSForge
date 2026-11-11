#!/bin/bash
# Verify that the details inspector renders output for the test container.
details_shows_vps() { local out; out=$(details "$T"); grep -q "VPS DETAILS INSPECTOR" <<<"$out"; }
