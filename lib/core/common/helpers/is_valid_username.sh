#!/bin/bash
# A username must be a safe POSIX login name.
is_valid_username() {
  [[ "${1:-}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}
