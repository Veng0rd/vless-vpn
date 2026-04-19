#!/bin/sh
set -eu

log() {
  printf '[rules-sync] %s\n' "$*"
}

download() {
  target="$1"
  url="$2"
  tmp_file="${target}.tmp"
  curl -fsSL "${url}" -o "${tmp_file}"
  mv "${tmp_file}" "${target}"
}

sync_once() {
  mkdir -p /output/rules

  download /output/rules/geoip.dat \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat
  download /output/rules/geosite.dat \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat

  download /output/rules/all.json \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/all.json
  download /output/rules/all_except_ru.json \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/all_except_ru.json
  download /output/rules/only_blocked.json \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/only_blocked.json
  download /output/rules/template.json \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/template.json
  download /output/rules/v2ray.json \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/v2ray.json
  download /output/rules/dns_v2ray_normal \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/dns_v2ray_normal
  download /output/rules/dns_singbox_normal \
    https://raw.githubusercontent.com/runetfreedom/russia-v2ray-custom-routing-list/main/v2rayN/dns_singbox_normal

  date -u +"%Y-%m-%dT%H:%M:%SZ" > /output/rules/LAST_SYNC_UTC
  log "routing artifacts refreshed"
}

interval="${RULES_SYNC_INTERVAL_SECONDS:-21600}"

case "${interval}" in
  ''|*[!0-9]*)
    log "RULES_SYNC_INTERVAL_SECONDS must be numeric, got: ${interval}"
    exit 1
    ;;
esac

while :; do
  sync_once
  sleep "${interval}"
done
