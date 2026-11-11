#!/bin/bash
# Print every website route on the server, one per line:
#   vps|domain|path|target|line_number
list_proxy_routes() {
  local file vps line trimmed n path target open_b close_b depth header d
  local -a words domains
  for file in "$CADDY_CONF_DIR"/*.caddy; do
    [ -e "$file" ] || continue
    vps=$(basename "$file" .caddy)
    domains=()
    depth=0
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      trimmed=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
      open_b=$(echo "$line" | tr -cd '{' | wc -c)
      close_b=$(echo "$line" | tr -cd '}' | wc -c)
      if [ "$depth" -eq 0 ] && [[ "$trimmed" == *"{"* ]] && [[ "$trimmed" != \#* ]] && [[ "$trimmed" != reverse_proxy* ]] && [[ "$trimmed" != transport* ]] && [[ "$trimmed" != tls_* ]]; then
        header="${trimmed%\{*}"
        domains=()
        for d in $header; do
          d="${d%,}"
          [ -n "$d" ] && domains+=("$d")
        done
      elif [[ "$trimmed" == reverse_proxy* ]]; then
        read -ra words <<< "$trimmed"
        if [ "${#words[@]}" -ge 3 ] && [[ "${words[1]}" == /* ]]; then
          path="${words[1]}"
          target="${words[2]}"
        else
          path="/"
          target="${words[1]}"
        fi
        for d in "${domains[@]}"; do
          echo "$vps|$d|$path|$target|$n"
        done
      fi
      depth=$((depth + open_b - close_b))
      [ "$depth" -le 0 ] && { depth=0; domains=(); }
    done < "$file"
  done
}
