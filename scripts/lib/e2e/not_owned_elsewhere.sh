#!/bin/bash
# Check that the test domain is not registered to any other container.
not_owned_elsewhere() { ! domain_used_by_other_vps "$pxy" "$T"; }
