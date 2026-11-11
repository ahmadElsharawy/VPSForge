#!/bin/bash
# Insert a reverse_proxy directive into a domain block within a Caddy config file.
#   _caddy_insert_proxy_line <conf_file> <domain> <proxy_line>
_caddy_insert_proxy_line() {
  local conf="$1" domain="$2" proxy_line="$3"
  if [ ! -f "$conf" ]; then
    printf '%s {\n%s\n}\n' "$domain" "$proxy_line" > "$conf"
    return 0
  fi

  local -a new_lines=()
  local in_domain=0 brace_count=0 inserted=0 line open_b close_b
  while IFS= read -r line; do
    if [ $inserted -eq 0 ]; then
      if [ $in_domain -eq 1 ]; then
        open_b=$(echo "$line" | tr -cd '{' | wc -c)
        close_b=$(echo "$line" | tr -cd '}' | wc -c)
        brace_count=$((brace_count + open_b - close_b))
        if [ $brace_count -le 0 ]; then
          new_lines+=("$proxy_line")
          inserted=1
        fi
      elif [[ "$line" == "$domain {"* ]] || [[ "$line" == "$domain,"* ]]; then
        in_domain=1
        brace_count=1
      fi
    fi
    new_lines+=("$line")
  done < "$conf"
  if [ $inserted -eq 0 ]; then
    new_lines+=("" "$domain {" "$proxy_line" "}")
  fi
  printf '%s\n' "${new_lines[@]}" > "$conf"
}
