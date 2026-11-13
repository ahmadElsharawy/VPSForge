#!/bin/bash
# Name of the temporary pool used while VPSs are moved to a new default pool. The name is kept from
# the first (dir -> BTRFS) version so a migration stopped by an older VPSForge can still be finished.
POOL_MIGRATION_TEMP="temp-btrfs"
