#!/bin/bash
# Available host disk space in megabytes.
host_free_mb() { df -m --output=avail / | tail -1 | tr -d ' '; }
