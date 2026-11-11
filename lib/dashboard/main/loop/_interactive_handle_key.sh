#!/bin/bash
# Processes a pressed key, updating the input buffer or returning the submitted choice.
_interactive_handle_key() {
  local char="$1"
  INTERACTIVE_SUBMITTED=""
  if [ -z "$char" ]; then
    if [ -z "$INPUT_BUFFER" ]; then
      return 2
    fi
    INTERACTIVE_SUBMITTED="$INPUT_BUFFER"
    INPUT_BUFFER=""
    echo
    return 0
  elif [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then
    if [ -n "$INPUT_BUFFER" ]; then
      INPUT_BUFFER="${INPUT_BUFFER%?}"
      printf "\b \b"
    fi
    return 1
  elif [[ "$char" =~ ^[0-9]$ ]]; then
    INPUT_BUFFER="${INPUT_BUFFER}${char}"
    printf "%s" "$char"
    return 1
  else
    return 1
  fi
}
