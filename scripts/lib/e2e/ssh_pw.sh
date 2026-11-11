#!/bin/bash
# Log in over SSH using password authentication without sshpass.
ssh_pw() { # user pass host cmd
  local u="$1" p="$2" h="$3" askpass rc; shift 3
  askpass=$(mktemp); chmod 700 "$askpass"
  {
    echo '#!/bin/sh'
    echo 'printf "%s\n" "$E2E_PW"'   # the password comes from the environment, never written to the file
  } > "$askpass"
  E2E_PW="$p" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force setsid \
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no -o ConnectTimeout=10 "$u@$h" "$@"
  rc=$?
  rm -f "$askpass"
  return "$rc"
}
