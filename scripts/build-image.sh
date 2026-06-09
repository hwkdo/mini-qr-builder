#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

# shellcheck source=/dev/null
source "${CONFIG_DIR}/build.env"

: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${DOCKER_IMAGE:?DOCKER_IMAGE is required}"

FRAME_PRESETS="$(jq -c . "${CONFIG_DIR}/frame-presets.json")"

# Logo: bevorzugt config/logo.png (wird beim Build als Data-URI eingebettet)
LOGO_FILE="${CONFIG_DIR}/logo.png"
if [[ -f "${LOGO_FILE}" ]]; then
  LOGO_B64="$(base64 -w0 "${LOGO_FILE}" 2>/dev/null || base64 "${LOGO_FILE}" | tr -d '\n')"
  QR_CODE_PRESETS="$(jq -c --arg img "data:image/png;base64,${LOGO_B64}" \
    'map(.image = $img)' "${CONFIG_DIR}/qr-code-presets.json")"
else
  QR_CODE_PRESETS="$(jq -c . "${CONFIG_DIR}/qr-code-presets.json")"
  if ! echo "${QR_CODE_PRESETS}" | jq -e '.[0].image | startswith("data:image/")' >/dev/null; then
    echo "Fehler: Lege dein Logo als ${LOGO_FILE} ab (PNG)." >&2
    echo "Alternativ: image-Feld in config/qr-code-presets.json mit data:image/...;base64,... setzen." >&2
    exit 1
  fi
fi

# Image-Tag ohne führendes "v" (z.B. 0.31.0 statt v0.31.0)
IMAGE_VERSION="${RELEASE_TAG#v}"
IMAGE_TAG="${DOCKER_IMAGE}:${IMAGE_VERSION}"

echo "Building ${IMAGE_TAG} from ${UPSTREAM_REPO}@${RELEASE_TAG}"

docker build \
  --build-arg "BASE_PATH=${BASE_PATH}" \
  --build-arg "VITE_HIDE_CREDITS=${VITE_HIDE_CREDITS}" \
  --build-arg "VITE_FRAME_PRESET=${VITE_FRAME_PRESET}" \
  --build-arg "VITE_FRAME_PRESETS=${FRAME_PRESETS}" \
  --build-arg "VITE_DEFAULT_PRESET=${VITE_DEFAULT_PRESET}" \
  --build-arg "VITE_QR_CODE_PRESETS=${QR_CODE_PRESETS}" \
  --build-arg "VITE_APP_VERSION=${RELEASE_TAG}" \
  -t "${IMAGE_TAG}" \
  -t "${DOCKER_IMAGE}:latest" \
  "${SOURCE_DIR}"

docker push "${IMAGE_TAG}"
docker push "${DOCKER_IMAGE}:latest"

echo "Pushed ${IMAGE_TAG} and ${DOCKER_IMAGE}:latest"
