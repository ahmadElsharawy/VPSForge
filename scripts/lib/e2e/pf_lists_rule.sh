#!/bin/bash
# Check whether the forwarded port 18081 is present in the port forward list.
pf_lists_rule() { local out; out=$(port_forward_list_rules); grep -q 18081 <<<"$out"; }
