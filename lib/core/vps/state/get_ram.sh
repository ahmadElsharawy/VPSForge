#!/bin/bash
# Read configured memory limit from container config.
get_ram() {
  incus config get "$1" limits.memory 2>/dev/null || true
}
