#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/versions/platform-assets.env"

DIST_DIR="${ROOT_DIR}/dist"
CACHE_DIR="${DIST_DIR}/cache"
MANIFEST_DIR="${CACHE_DIR}/manifests"
CHART_DIR="${CACHE_DIR}/charts"
K3S_DIR="${CACHE_DIR}/k3s"

mkdir -p "${MANIFEST_DIR}" "${CHART_DIR}" "${K3S_DIR}"

download() {
  local url="$1"
  local target="$2"
  local tmp="${target}.tmp"

  curl --http1.1 -fsSL --retry 5 --retry-delay 3 --connect-timeout 30 --max-time 240 "${url}" -o "${tmp}"
  mv "${tmp}" "${target}"
}

manifest_name() {
  local url="$1"
  printf '%s' "${url}" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-180
}

download "${GATEWAY_API_URL}" "${MANIFEST_DIR}/$(manifest_name "${GATEWAY_API_URL}").yaml"
download "${ARGO_CD_URL}" "${MANIFEST_DIR}/$(manifest_name "${ARGO_CD_URL}").yaml"
download "${ARGO_ROLLOUTS_URL}" "${MANIFEST_DIR}/$(manifest_name "${ARGO_ROLLOUTS_URL}").yaml"
download "${CILIUM_CHART_URL}" "${CHART_DIR}/cilium-${CILIUM_VERSION}.tgz"
download "${K3S_INSTALL_SCRIPT_URL}" "${K3S_DIR}/install-${K3S_VERSION}.sh"
download "${K3S_BINARY_URL}" "${K3S_DIR}/k3s-${K3S_VERSION}"
download "${K3S_AIRGAP_IMAGES_URL}" "${K3S_DIR}/k3s-airgap-images-${K3S_VERSION}-${K3S_ARCH}.tar.zst"

BUNDLE_NAME="kadm-platform-assets-k3s-${K3S_VERSION}-gateway-${GATEWAY_API_VERSION}-argocd-${ARGO_CD_VERSION}-rollouts-${ARGO_ROLLOUTS_VERSION}-cilium-${CILIUM_VERSION}.tgz"
tar -czf "${DIST_DIR}/${BUNDLE_NAME}" -C "${DIST_DIR}" cache
cp "${DIST_DIR}/${BUNDLE_NAME}" "${DIST_DIR}/kadm-platform-assets.tgz"

echo "bundle written: ${DIST_DIR}/${BUNDLE_NAME}"
