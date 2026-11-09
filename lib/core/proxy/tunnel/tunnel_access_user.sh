#!/bin/bash
# Name of the limited login that exists only to open ONE tunnel port (it cannot do anything else on the VPS).
#   tunnel_access_user <tunnel_port>
tunnel_access_user() {
  echo "vftun${1:?tunnel port}"
}
