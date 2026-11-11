#!/bin/bash
# Check whether detected backend service scheme on port 8088 is HTTP.
scheme_is_http() { test "$(detect_backend_scheme "$ip" 8088)" = "http"; }
