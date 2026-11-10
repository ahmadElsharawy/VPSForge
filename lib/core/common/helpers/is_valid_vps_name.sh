#!/bin/bash
# A VPS name must be a name Incus accepts (checked on a real host): letters,
# digits and dashes, at most 63 characters, not starting or ending with a dash,
# and not only digits.
is_valid_vps_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && [[ "$name" != *- ]] && ! [[ "$name" =~ ^[0-9]+$ ]]
}
