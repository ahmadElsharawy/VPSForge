#!/bin/bash
# Forget the pending-operation record of <name> (the operation finished or was cleaned up).
#   pending_operation_clear <name>
pending_operation_clear() {
  rm -f "$PENDING_DIR/${1:?name}" 2>/dev/null
  return 0
}
