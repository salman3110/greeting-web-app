#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-greeting-web-app:test}"
HOST_PORT="${TEST_HOST_PORT:-18080}"
CONTAINER_PORT="${TEST_CONTAINER_PORT:-18081}"
NAME="greeting-web-app-smoke-${RANDOM}"
EXPECTED_GREETING="Smoke test greeting"

cleanup() {
  docker rm -f "${NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test the container for production-style security
docker run -d \
  --name "${NAME}" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  -e PORT="${CONTAINER_PORT}" \
  -e GREETING="${EXPECTED_GREETING}" \
  -p "127.0.0.1:${HOST_PORT}:${CONTAINER_PORT}" \
  "${IMAGE}" >/dev/null

for _ in $(seq 1 30); do
  if curl --fail --silent "http://127.0.0.1:${HOST_PORT}/healthz" >/dev/null; then
    break
  fi
  sleep 1
done

curl --fail --silent "http://127.0.0.1:${HOST_PORT}/healthz" | grep -q '"status":"ok"'
curl --fail --silent "http://127.0.0.1:${HOST_PORT}/" | grep -q "${EXPECTED_GREETING}"
curl --fail --silent "http://127.0.0.1:${HOST_PORT}/info" | grep -q "\"port\":${CONTAINER_PORT}"

uid="$(docker exec "${NAME}" id -u)"
if [[ "${uid}" == "0" ]]; then
  echo "ERROR: container is running as root" >&2
  exit 1
fi

echo "Container smoke tests passed (uid=${uid})."
