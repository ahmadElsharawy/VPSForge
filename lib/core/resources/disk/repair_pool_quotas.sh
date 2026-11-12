#!/bin/bash
# Make the VPS disk limits work again when btrfs marked its quota data "inconsistent".
# Deleting a VPS, image or snapshot can set that mark (kernel log: "qgroup marked inconsistent");
# while it is set, NO disk limit is enforced and every VPS shows a tiny usage. A rescan fixes
# both. Does nothing (and costs a few milliseconds) when the data is fine or the pool is not btrfs.
#   repair_pool_quotas
repair_pool_quotas() {
  local pool_path
  command -v btrfs >/dev/null 2>&1 || return 0
  pool_path=$(get_incus_pool_path)
  [ "$(stat -f -c %T "$pool_path" 2>/dev/null)" = "btrfs" ] || return 0
  btrfs qgroup show "$pool_path" 2>&1 | grep -qi 'inconsistent' || return 0
  btrfs quota rescan -w "$pool_path" >/dev/null 2>&1 || true
  return 0
}
