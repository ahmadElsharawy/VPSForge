#!/bin/bash
# Print a short "what to type" hint under a question, in the same style everywhere.
#   show_example "8080  -> people open http://YOUR-SERVER-IP:8080"
show_example() {
  echo "    e.g.  $*"
}
