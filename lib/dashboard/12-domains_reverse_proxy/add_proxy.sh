#!/bin/bash

add_path_to_vps() {
  local vps_name="$1"
  local ip="$2"
  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  local domain=""
  if [ ! -f "$conf_file" ]; then
    read -r -p "Enter Domain Name for this VPS (e.g. app1.domain.com, 0=Back): " domain
    [ "$domain" = "0" ] && return
    if [ -z "$domain" ]; then
      echo "ERROR: Domain cannot be empty."
      sleep 2
      return
    fi
  else
    local existing_domain
    existing_domain=$(head -n 1 "$conf_file" | awk '{print $1}')
    read -r -p "Enter Domain Name [0=Back, Enter=$existing_domain]: " domain
    [ "$domain" = "0" ] && return
    [ -z "$domain" ] && domain="$existing_domain"
  fi

  read -r -p "Enter Path (e.g. /sub/ or leave empty for root '/') [Enter=/]: " url_path
  if [ -z "$url_path" ] || [ "$url_path" = "/" ]; then
    url_path=""
  else
    [[ "$url_path" != /* ]] && url_path="/$url_path"
    if [[ "$url_path" != *\* ]]; then
      if [[ "$url_path" != */ ]]; then
        url_path="${url_path}/*"
      else
        url_path="${url_path}*"
      fi
    fi
  fi

  read -r -p "Enter target port inside VPS [Enter=80]: " target_port
  [ -z "$target_port" ] && target_port="80"

  read -r -p "Is the target using HTTPS internally? (y/N) [Enter=N]: " use_https
  
  local target_schema="http"
  local caddy_transport=""
  if [[ "$use_https" =~ ^[Yy]$ ]]; then
    target_schema="https"
    caddy_transport=" {
        transport http {
            tls_insecure_skip_verify
        }
    }"
  fi

  local proxy_line=""
  if [ -n "$url_path" ]; then
    proxy_line="    reverse_proxy $url_path ${target_schema}://$ip:$target_port$caddy_transport"
  else
    proxy_line="    reverse_proxy ${target_schema}://$ip:$target_port$caddy_transport"
  fi

  if [ ! -f "$conf_file" ]; then
    echo "$domain {" > "$conf_file"
    echo "$proxy_line" >> "$conf_file"
    echo "}" >> "$conf_file"
  else
    local -a new_lines=()
    local in_domain=0
    local brace_count=0
    local inserted=0

    while IFS= read -r line; do
      if [ $inserted -eq 0 ]; then
        if [ $in_domain -eq 1 ]; then
          local open_b=$(echo "$line" | tr -cd '{' | wc -c)
          local close_b=$(echo "$line" | tr -cd '}' | wc -c)
          brace_count=$((brace_count + open_b - close_b))
          
          if [ $brace_count -le 0 ]; then
            new_lines+=("$proxy_line")
            inserted=1
          fi
        else
          if [[ "$line" == "$domain {"* ]] || [[ "$line" == "$domain,"* ]]; then
            in_domain=1
            brace_count=1
          fi
        fi
      fi
      new_lines+=("$line")
    done < "$conf_file"

    if [ $inserted -eq 0 ]; then
      new_lines+=("")
      new_lines+=("$domain {")
      new_lines+=("$proxy_line")
      new_lines+=("}")
    fi

    printf "%s\n" "${new_lines[@]}" > "$conf_file"
  fi

  echo "Validating Caddy configuration..."
  if caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
    systemctl reload-or-restart caddy
    incus exec "$vps_name" -- sh -c "grep -qF '$domain' /etc/hosts || echo '127.0.0.1 $domain' >> /etc/hosts" 2>/dev/null || true
    echo "SUCCESS: $domain$url_path is now securely routed to $vps_name (${target_schema}://$ip:$target_port)"
  else
    echo "ERROR: Invalid configuration! Opening file in nano so you can fix it manually..."
    sleep 2
    nano "$conf_file"
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  fi
}
