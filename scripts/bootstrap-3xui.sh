#!/bin/sh
set -eu

log() {
  printf '[bootstrap] %s\n' "$*"
}

normalize_base_path() {
  path="${1:-}"
  if [ -z "$path" ] || [ "$path" = "/" ]; then
    printf ''
    return
  fi
  path="/${path#/}"
  path="${path%/}"
  printf '%s' "$path"
}

random_hex() {
  bytes="$1"
  hexdump -vn "$bytes" -e '/1 "%02x"' /dev/urandom
}

random_token() {
  size="$1"
  tr -dc 'a-z0-9' </dev/urandom | head -c "$size"
}

build_string_array() {
  printf '%s' "$1" \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^$/d' \
    | jq -Rsc 'split("\n") | map(select(length > 0))'
}

PANEL_API_BASE="${PANEL_API_BASE:-http://127.0.0.1:2053}"
PANEL_WEB_BASE_PATH="$(normalize_base_path "${PANEL_WEB_BASE_PATH:-}")"
PANEL_ROOT="${PANEL_API_BASE%/}${PANEL_WEB_BASE_PATH}"
LOGIN_URL="${PANEL_ROOT}/login"
API_ROOT="${PANEL_ROOT}/panel/api"
COOKIE_JAR="/tmp/3xui.cookies"

PANEL_USERNAME="${PANEL_USERNAME:-admin}"
PANEL_PASSWORD="${PANEL_PASSWORD:-admin}"
OUTPUT_HOST="${OUTPUT_HOST:-SERVER_PUBLIC_IP}"
VLESS_PORT="${VLESS_PORT:-443}"
VLESS_REMARK="${VLESS_REMARK:-nl-reality-main}"
VLESS_CLIENT_EMAIL="${VLESS_CLIENT_EMAIL:-primary@local}"
REALITY_DEST="${REALITY_DEST:-www.microsoft.com:443}"
REALITY_SERVER_NAMES="${REALITY_SERVER_NAMES:-www.microsoft.com,dl.google.com,www.apple.com,gateway.icloud.com}"
REALITY_FINGERPRINT="${REALITY_FINGERPRINT:-chrome}"
REALITY_SPIDER_X="${REALITY_SPIDER_X:-/}"

OUTPUT_DIR="/output/client"
mkdir -p "${OUTPUT_DIR}"

case "${VLESS_PORT}" in
  ''|*[!0-9]*)
    log "VLESS_PORT must be numeric, got: ${VLESS_PORT}"
    exit 1
    ;;
esac

log "waiting for 3x-ui at ${PANEL_ROOT}/"
tries=0
until curl -fsSL "${PANEL_ROOT}/" >/dev/null 2>&1; do
  tries=$((tries + 1))
  if [ "${tries}" -ge 60 ]; then
    log "3x-ui did not become ready in time"
    exit 1
  fi
  sleep 2
done

login_payload="$(jq -nc \
  --arg username "${PANEL_USERNAME}" \
  --arg password "${PANEL_PASSWORD}" \
  '{username: $username, password: $password}')"

login_response="$(curl -fsS \
  -c "${COOKIE_JAR}" \
  -H 'Content-Type: application/json' \
  -d "${login_payload}" \
  "${LOGIN_URL}")"

if ! printf '%s' "${login_response}" | jq -e '(.success // true) == true' >/dev/null; then
  log "panel login failed"
  printf '%s\n' "${login_response}" > "${OUTPUT_DIR}/bootstrap-login-error.json"
  exit 1
fi

log "logged in to 3x-ui API"

inbounds_response="$(curl -fsS -b "${COOKIE_JAR}" "${API_ROOT}/inbounds/list")"
if ! printf '%s' "${inbounds_response}" | jq -e '(.success // true) == true' >/dev/null; then
  log "failed to query inbounds list"
  printf '%s\n' "${inbounds_response}" > "${OUTPUT_DIR}/bootstrap-inbounds-error.json"
  exit 1
fi

existing_inbound="$(printf '%s' "${inbounds_response}" \
  | jq -c --argjson port "${VLESS_PORT}" '.obj[]? | select(.port == $port and .protocol == "vless")' \
  | head -n 1)"

if [ -z "${existing_inbound}" ]; then
  log "no vless inbound on port ${VLESS_PORT}; creating one"

  if [ -n "${VLESS_UUID:-}" ]; then
    vless_uuid="${VLESS_UUID}"
  else
    uuid_response="$(curl -fsS -b "${COOKIE_JAR}" "${API_ROOT}/server/getNewUUID")"
    vless_uuid="$(printf '%s' "${uuid_response}" | jq -r '.obj.uuid')"
  fi

  x25519_response="$(curl -fsS -b "${COOKIE_JAR}" "${API_ROOT}/server/getNewX25519Cert")"
  reality_private_key="$(printf '%s' "${x25519_response}" | jq -r '.obj.privateKey')"
  reality_public_key="$(printf '%s' "${x25519_response}" | jq -r '.obj.publicKey')"

  server_names_json="$(build_string_array "${REALITY_SERVER_NAMES}")"
  selected_sni="$(printf '%s' "${server_names_json}" | jq -r '.[0]')"

  if [ -n "${REALITY_SHORT_IDS:-}" ]; then
    short_ids_json="$(build_string_array "${REALITY_SHORT_IDS}")"
  else
    sid1="$(random_hex 4)"
    sid2="$(random_hex 4)"
    sid3="$(random_hex 4)"
    sid4="$(random_hex 4)"
    short_ids_json="$(printf '%s\n%s\n%s\n%s\n' "${sid1}" "${sid2}" "${sid3}" "${sid4}" \
      | jq -Rsc 'split("\n") | map(select(length > 0))')"
  fi

  selected_short_id="$(printf '%s' "${short_ids_json}" | jq -r '.[0]')"
  client_sub_id="$(random_token 16)"

  settings_json="$(jq -nc \
    --arg uuid "${vless_uuid}" \
    --arg email "${VLESS_CLIENT_EMAIL}" \
    --arg subId "${client_sub_id}" \
    '{
      clients: [{
        id: $uuid,
        flow: "",
        email: $email,
        limitIp: 0,
        totalGB: 0,
        expiryTime: 0,
        enable: true,
        tgId: "",
        subId: $subId,
        reset: 0
      }],
      decryption: "none",
      fallbacks: []
    }')"

  stream_settings_json="$(jq -nc \
    --arg dest "${REALITY_DEST}" \
    --arg privateKey "${reality_private_key}" \
    --arg publicKey "${reality_public_key}" \
    --arg fingerprint "${REALITY_FINGERPRINT}" \
    --arg spiderX "${REALITY_SPIDER_X}" \
    --argjson serverNames "${server_names_json}" \
    --argjson shortIds "${short_ids_json}" \
    '{
      network: "tcp",
      security: "reality",
      externalProxy: [],
      realitySettings: {
        show: false,
        xver: 0,
        dest: $dest,
        serverNames: $serverNames,
        privateKey: $privateKey,
        minClient: "",
        maxClient: "",
        maxTimediff: 0,
        shortIds: $shortIds,
        settings: {
          publicKey: $publicKey,
          fingerprint: $fingerprint,
          serverName: "",
          spiderX: $spiderX
        }
      },
      tcpSettings: {
        acceptProxyProtocol: false,
        header: {
          type: "none"
        }
      }
    }')"

  sniffing_json='{"enabled":true,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
  allocate_json='{"strategy":"always","refresh":5,"concurrency":3}'

  create_payload="$(jq -nc \
    --arg remark "${VLESS_REMARK}" \
    --arg settings "${settings_json}" \
    --arg streamSettings "${stream_settings_json}" \
    --arg sniffing "${sniffing_json}" \
    --arg allocate "${allocate_json}" \
    --argjson port "${VLESS_PORT}" \
    '{
      up: 0,
      down: 0,
      total: 0,
      remark: $remark,
      enable: true,
      expiryTime: 0,
      listen: "",
      port: $port,
      protocol: "vless",
      settings: $settings,
      streamSettings: $streamSettings,
      sniffing: $sniffing,
      allocate: $allocate
    }')"

  create_response="$(curl -fsS \
    -b "${COOKIE_JAR}" \
    -H 'Content-Type: application/json' \
    -d "${create_payload}" \
    "${API_ROOT}/inbounds/add")"

  if ! printf '%s' "${create_response}" | jq -e '.success == true' >/dev/null; then
    log "failed to create inbound"
    printf '%s\n' "${create_response}" > "${OUTPUT_DIR}/bootstrap-create-error.json"
    exit 1
  fi

  existing_inbound="$(printf '%s' "${create_response}" | jq -c '.obj')"
  log "inbound created on port ${VLESS_PORT}"
else
  log "reusing existing vless inbound on port ${VLESS_PORT}"
fi

settings_raw="$(printf '%s' "${existing_inbound}" | jq -r '.settings')"
stream_raw="$(printf '%s' "${existing_inbound}" | jq -r '.streamSettings')"

vless_uuid="$(printf '%s' "${settings_raw}" | jq -r '.clients[0].id')"
vless_email="$(printf '%s' "${settings_raw}" | jq -r '.clients[0].email')"
public_key="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.settings.publicKey')"
selected_sni="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.serverNames[0]')"
selected_short_id="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.shortIds[0]')"
fingerprint="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.settings.fingerprint // "chrome"')"
spider_x="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.settings.spiderX // "/"')"
dest_value="$(printf '%s' "${stream_raw}" | jq -r '.realitySettings.dest')"
server_names_pretty="$(printf '%s' "${stream_raw}" | jq '.realitySettings.serverNames')"
short_ids_pretty="$(printf '%s' "${stream_raw}" | jq '.realitySettings.shortIds')"
remark_value="$(printf '%s' "${existing_inbound}" | jq -r '.remark')"

encoded_spider_x="$(jq -nr --arg value "${spider_x}" '$value|@uri')"
encoded_remark="$(jq -nr --arg value "${remark_value}" '$value|@uri')"

vless_uri="vless://${vless_uuid}@${OUTPUT_HOST}:${VLESS_PORT}?type=tcp&security=reality&encryption=none&pbk=${public_key}&fp=${fingerprint}&sni=${selected_sni}&sid=${selected_short_id}&spx=${encoded_spider_x}#${encoded_remark}"

printf '%s\n' "${vless_uri}" > "${OUTPUT_DIR}/vless-uri.txt"

jq -n \
  --arg host "${OUTPUT_HOST}" \
  --argjson port "${VLESS_PORT}" \
  --arg remark "${remark_value}" \
  --arg uuid "${vless_uuid}" \
  --arg email "${vless_email}" \
  --arg publicKey "${public_key}" \
  --arg sni "${selected_sni}" \
  --arg shortId "${selected_short_id}" \
  --arg fingerprint "${fingerprint}" \
  --arg spiderX "${spider_x}" \
  --arg dest "${dest_value}" \
  --argjson serverNames "${server_names_pretty}" \
  --argjson shortIds "${short_ids_pretty}" \
  '{
    host: $host,
    port: $port,
    remark: $remark,
    uuid: $uuid,
    email: $email,
    reality: {
      publicKey: $publicKey,
      serverName: $sni,
      shortId: $shortId,
      fingerprint: $fingerprint,
      spiderX: $spiderX,
      dest: $dest,
      serverNames: $serverNames,
      shortIds: $shortIds
    }
  }' > "${OUTPUT_DIR}/connection-info.json"

cat > "${OUTPUT_DIR}/IMPORT-NOTES.txt" <<EOF
1. Import output/client/vless-uri.txt into your client.
2. Enable TUN mode on the client.
3. Update geo files in the client.
4. For v2rayN/v2rayNG, import templates/v2rayn-routing-custom.json.
5. Keep Russian services in direct route and the rest through proxy.

Panel URL: ${PANEL_ROOT}/
Panel credentials used by bootstrap: ${PANEL_USERNAME} / ${PANEL_PASSWORD}
Remember to change admin credentials after first login.
EOF

log "client artifacts written to ${OUTPUT_DIR}"
