#!/bin/bash
# Cleanup callback for run_guarded test recording failure reason.
guard_cleanup() { GUARD_CLEANED="cleaned:$1"; }
