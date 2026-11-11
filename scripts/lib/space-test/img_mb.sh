#!/bin/bash
# Size of the Incus default disk image file on disk in megabytes.
img_mb() { [ -f "$IMG" ] && du -sm "$IMG" | cut -f1 || echo 0; }
