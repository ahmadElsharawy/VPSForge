#!/bin/bash
# Print every website route on the server, one per line:
#   vps|domain|path|target|line_number
list_proxy_routes() {
  local file vps line trimmed domain n path target
  local -a words
  for file in "$CADDY_CONF_DIR"/*.caddy; do
    [ -e "$file" ] || continue
    vps=$(basename "$file" .caddy)
    domain=""
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      trimmed=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
      if [[ "$trimmed" == *"{" ]] && [[ "$trimmed" != reverse_proxy* ]] && [[ "$trimmed" != transport* ]] && [[ "$trimmed" != tls_* ]]; then
        domain=$(echo "$trimmed" | awk '{print $1}')
        domain=${domain%,}
        domain=${domain%\{}
      elif [[ "$trimmed" == reverse_proxy* ]]; then
        read -ra words <<< "$trimmed"
        if [ "${#words[@]}" -ge 3 ] && [[ "${words[1]}" == /* ]]; then
          path="${words[1]}"
          target="${words[2]}"
        else
          path="/"
          target="${words[1]}"
        fi
        echo "$vps|$domain|$path|$target|$n"
      fi
    done < "$file"
  done
}
