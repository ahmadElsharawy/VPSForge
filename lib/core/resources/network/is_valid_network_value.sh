#!/bin/bash
# Succeeds when <value> is a speed between 1 and 100000 Mbit.
is_valid_network_value() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 100000 ]
}
