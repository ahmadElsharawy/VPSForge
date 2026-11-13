#!/bin/bash
# Automatic upgrade (at setup) of an old "dir" default pool: see migrate_default_pool.
migrate_default_pool_to_btrfs() {
  migrate_default_pool dir
}
