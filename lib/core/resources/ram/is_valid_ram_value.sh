#!/bin/bash
# Succeeds when <value> is a whole number of MB that is at least MIN_RAM_MB.
is_valid_ram_value() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge "$MIN_RAM_MB" ]
}
