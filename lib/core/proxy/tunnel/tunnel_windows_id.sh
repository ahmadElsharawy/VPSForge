#!/bin/bash
# Short name that tells tunnels apart on the Windows PC (server + its ssh port + tunnel port), e.g. 1_2_3_4_9001_5789.
#   tunnel_windows_id <server_ip> <ssh_port> <tunnel_port>
tunnel_windows_id() {
  local host="${1:?host}" sshport="${2:?port}" tport="${3:?tunnel port}"
  echo "${host//./_}_${sshport}_${tport}"
}
