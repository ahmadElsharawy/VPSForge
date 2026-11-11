#!/bin/bash
# Record test result and print failure details if actual value does not match expected.
t() { # t "description" expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1 (expected '$2', got '$3')"; fi
}
