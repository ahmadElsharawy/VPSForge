#!/bin/bash
# Failing operation callback for run_guarded test.
guard_fail() { echo "ERROR: disk is full"; return 1; }
