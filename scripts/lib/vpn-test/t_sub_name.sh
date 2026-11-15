#!/bin/bash
# Check that the links of subscription URL $1 carry the name $2 (days and GB left).
t_sub_name() { curl -fsS -m 5 "$1" | base64 -d | grep -q "#$2-REALITY$"; }
