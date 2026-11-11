#!/bin/bash
# Read a configuration key from the test container.
cfg() { incus config get "$T" "$1"; }
