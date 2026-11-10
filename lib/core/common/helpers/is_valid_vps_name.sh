#!/bin/bash
# A VPS name must be a name Incus accepts: starts with a letter, then letters,
# digits or dashes, at most 63 characters, not ending with a dash.
is_valid_vps_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[a-zA-Z][a-zA-Z0-9-]{0,62}$ ]] && [[ "$name" != *- ]]
}
