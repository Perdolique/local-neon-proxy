#!/bin/bash

set -Eeuo pipefail

proxy_pid=''
caddy_pid=''

terminate() {
  if [[ -n "$proxy_pid" ]]; then
    kill -TERM "$proxy_pid" 2>/dev/null || true
  fi

  if [[ -n "$caddy_pid" ]]; then
    kill -TERM "$caddy_pid" 2>/dev/null || true
  fi
}

trap terminate TERM INT

if [[ -z "${PG_CONNECTION_STRING:-}" ]]; then
  echo "PG_CONNECTION_STRING is not set" >&2
  exit 1
fi

umask 077
openssl req -new -x509 \
  -days 365 \
  -nodes \
  -sha256 \
  -out server.pem \
  -keyout server.key \
  -subj "/CN=*.localtest.me" \
  -addext "subjectAltName = DNS:*.localtest.me"

# Create required tables
psql -v ON_ERROR_STOP=1 -Atx "$PG_CONNECTION_STRING" \
  -c "CREATE SCHEMA IF NOT EXISTS neon_control_plane" \
  -c "CREATE TABLE IF NOT EXISTS neon_control_plane.endpoints (endpoint_id VARCHAR(255) PRIMARY KEY, allowed_ips VARCHAR(255))"

# Start the neon-proxy
./neon-proxy \
  -c server.pem \
  -k server.key \
  --auth-backend=postgres \
  --auth-endpoint="$PG_CONNECTION_STRING" \
  --wss=0.0.0.0:4445 \
  &
proxy_pid=$!

# Start caddy reverse proxy
caddy run \
  --config ./Caddyfile \
  --adapter caddyfile \
  &
caddy_pid=$!

set +e
wait -n "$proxy_pid" "$caddy_pid"
status=$?
set -e

terminate
wait "$proxy_pid" "$caddy_pid" 2>/dev/null || true

exit "$status"
