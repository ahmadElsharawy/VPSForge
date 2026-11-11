#!/bin/bash
# Validate the active Caddyfile configuration syntax.
caddy_valid() { caddy validate --config "$MAIN_CADDYFILE"; }
