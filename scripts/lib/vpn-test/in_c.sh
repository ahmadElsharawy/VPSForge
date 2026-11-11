#!/bin/bash
# Execute a shell command inside the client test container.
in_c() { incus exec "$C" -- sh -c "$1" </dev/null; }
