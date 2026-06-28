#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/versions/platform-assets.env"

LIST_IMAGES_ONLY=0
SKIP_IMAGE_EXPORT=0
OFFLINE_COMPLETE=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-images)
      LIST_IMAGES_ONLY=1
      SKIP_IMAGE_EXPORT=1
      shift
      ;;
    --skip-image-export)
      SKIP_IMAGE_EXPORT=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/build-bundle.sh [--list-images] [--skip-image-export]

Options:
  --list-images        Print the generated runtime image list and exit.
  --skip-image-export  Build metadata and caches without pulling/saving images.
USAGE
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

DIST_DIR="${ROOT_DIR}/dist"
CACHE_DIR="${DIST_DIR}/cache"
MANIFEST_DIR="${CACHE_DIR}/manifests"
CHART_DIR="${CACHE_DIR}/charts"
K3S_DIR="${CACHE_DIR}/k3s"
TOOL_DIR="${CACHE_DIR}/tools"
IMAGE_DIR="${CACHE_DIR}/images"
REPO_DIR="${CACHE_DIR}/repos"
SOURCE_DIR="${DIST_DIR}/sources"
METADATA_DIR="${DIST_DIR}/metadata"

rm -rf "${CACHE_DIR}" "${SOURCE_DIR}" "${METADATA_DIR}"
mkdir -p \
  "${MANIFEST_DIR}" \
  "${CHART_DIR}" \
  "${K3S_DIR}" \
  "${TOOL_DIR}" \
  "${IMAGE_DIR}" \
  "${REPO_DIR}" \
  "${SOURCE_DIR}" \
  "${METADATA_DIR}"

github_url_uses_token() {
  local url="$1"
  [[ "${url}" == https://api.github.com/* || "${url}" == https://github.com/* || "${url}" == https://raw.githubusercontent.com/* ]]
}

curl_supports_retry_all_errors() {
  curl --help all 2>/dev/null | grep -q -- "--retry-all-errors"
}

download() {
  local url="$1"
  local target="$2"
  local tmp="${target}.tmp"
  local curl_args=(
    --http1.1
    -fsSL
    --retry 5
    --retry-delay 3
    --connect-timeout 30
    --max-time 1800
  )

  if curl_supports_retry_all_errors; then
    curl_args+=(--retry-all-errors)
  fi

  if [[ -n "${KADM_GITHUB_TOKEN:-}" ]] && github_url_uses_token "${url}"; then
    curl_args+=(
      -H "Authorization: Bearer ${KADM_GITHUB_TOKEN}"
      -H "X-GitHub-Api-Version: 2022-11-28"
    )
  fi

  mkdir -p "$(dirname "${target}")"
  curl "${curl_args[@]}" "${url}" -o "${tmp}"
  mv "${tmp}" "${target}"
}

manifest_name() {
  local url="$1"
  printf '%s' "${url}" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-180
}

manifest_path() {
  local url="$1"
  echo "${MANIFEST_DIR}/$(manifest_name "${url}").yaml"
}

extract_repo_archive() {
  local archive="$1"
  local target_dir="$2"
  local tmp_extract extracted_dir
  tmp_extract="$(mktemp -d)"
  tar -xzf "${archive}" -C "${tmp_extract}"
  extracted_dir="$(find "${tmp_extract}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -n "${extracted_dir}" ]] || {
    rm -rf "${tmp_extract}"
    echo "error: failed to extract ${archive}" >&2
    exit 1
  }
  rm -rf "${target_dir}"
  mkdir -p "$(dirname "${target_dir}")"
  mv "${extracted_dir}" "${target_dir}"
  rm -rf "${tmp_extract}"
}

download_repo_archive() {
  local repo="$1"
  local ref="$2"
  local archive="${REPO_DIR}/${repo}.tgz"
  local target_dir="${SOURCE_DIR}/${repo}"

  if [[ -d "${ROOT_DIR}/../${repo}" ]]; then
    tar --exclude .git -czf "${archive}" -C "${ROOT_DIR}/.." "${repo}"
    rm -rf "${target_dir}"
    mkdir -p "${target_dir}"
    tar -xzf "${archive}" -C "${SOURCE_DIR}"
    return 0
  fi

  download "https://api.github.com/repos/${GITHUB_OWNER}/${repo}/tarball/${ref}" "${archive}"
  extract_repo_archive "${archive}" "${target_dir}"
}

image_from_kustomization() {
  local file="$1"
  awk '
    /^[[:space:]]*newName:[[:space:]]*/ {
      name = $0
      sub(/^[[:space:]]*newName:[[:space:]]*/, "", name)
    }
    /^[[:space:]]*newTag:[[:space:]]*/ {
      tag = $0
      sub(/^[[:space:]]*newTag:[[:space:]]*/, "", tag)
      if (name != "" && tag != "") {
        print name ":" tag
        name = ""
        tag = ""
      }
    }
  ' "${file}"
}

image_from_manifest() {
  local file="$1"
  awk '
    /^[[:space:]-]*image:[[:space:]]*/ {
      image = $0
      sub(/^[[:space:]-]*image:[[:space:]]*/, "", image)
      sub(/[[:space:]]*#.*/, "", image)
      gsub(/^[[:space:]"]+/, "", image)
      gsub(/[[:space:]"]+$/, "", image)
      if (image != "" && image !~ /^\{\{/ && image !~ /^\$/ && image ~ /[:@]/) {
        print image
      }
    }
  ' "${file}"
}

write_runtime_image_list() {
  local output="$1"
  local release_console_dir="${SOURCE_DIR}/${KADM_RELEASE_CONSOLE_REPO}"

  {
    image_from_manifest "$(manifest_path "${ARGO_CD_URL}")"
    image_from_manifest "$(manifest_path "${ARGO_ROLLOUTS_URL}")"
    printf '%s\n' "${CILIUM_AGENT_IMAGE}"
    printf '%s\n' "${CILIUM_OPERATOR_IMAGE}"
    printf '%s\n' "${CILIUM_ENVOY_IMAGE}"
    printf '%s\n' "${CILIUM_CERTGEN_IMAGE}"
    printf '%s\n' "${CILIUM_STARTUP_SCRIPT_IMAGE}"
    image_from_kustomization "${release_console_dir}/k8s/overlays/prod/kustomization.yaml"
  } | awk 'NF && !seen[$0]++' > "${output}"
}

docker_login_if_configured() {
  if [[ -n "${KADM_GHCR_USERNAME:-}" || -n "${KADM_GHCR_TOKEN:-}" ]]; then
    [[ -n "${KADM_GHCR_USERNAME:-}" && -n "${KADM_GHCR_TOKEN:-}" ]] || {
      echo "error: KADM_GHCR_USERNAME and KADM_GHCR_TOKEN must be set together" >&2
      exit 1
    }
    printf '%s' "${KADM_GHCR_TOKEN}" | docker login ghcr.io -u "${KADM_GHCR_USERNAME}" --password-stdin
  fi
}

export_runtime_images() {
  local list_file="$1"
  local archive="${IMAGE_DIR}/runtime-images.tar.zst"
  local tmp_tar="${IMAGE_DIR}/runtime-images.tar"
  local images=()

  command -v docker >/dev/null 2>&1 || {
    echo "error: docker is required to export runtime images" >&2
    exit 1
  }
  command -v zstd >/dev/null 2>&1 || {
    echo "error: zstd is required to compress runtime images" >&2
    exit 1
  }

  docker_login_if_configured
  while IFS= read -r image; do
    [[ -n "${image}" ]] || continue
    docker pull "${image}"
    images+=("${image}")
  done < "${list_file}"

  [[ "${#images[@]}" -gt 0 ]] || {
    echo "error: runtime image list is empty" >&2
    exit 1
  }

  docker save "${images[@]}" -o "${tmp_tar}"
  zstd -T0 -19 -f "${tmp_tar}" -o "${archive}"
  rm -f "${tmp_tar}"
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}"
  else
    shasum -a 256 "${file}"
  fi
}

write_checksums() {
  if [[ -s "${IMAGE_DIR}/runtime-images.tar.zst" ]]; then
    sha256_file "${IMAGE_DIR}/runtime-images.tar.zst" > "${IMAGE_DIR}/runtime-images.sha256"
  fi

  (
    cd "${DIST_DIR}"
    find cache metadata -type f -print | sort | while read -r file; do
      sha256_file "${file}"
    done
  ) > "${METADATA_DIR}/checksums.sha256"
}

write_metadata() {
  cat > "${METADATA_DIR}/offline-bundle.env" <<ENV
KADM_OFFLINE_BUNDLE_FORMAT=2
KADM_OFFLINE_COMPLETE=${OFFLINE_COMPLETE}
KADM_OFFLINE_IMAGE_IMPORT=containerd
KADM_OFFLINE_ARCH=${HELM_PLATFORM}
KADM_K3S_VERSION=${K3S_VERSION}
KADM_CILIUM_VERSION=${CILIUM_VERSION}
KADM_ARGOCD_VERSION=${ARGO_CD_VERSION}
KADM_ARGO_ROLLOUTS_VERSION=${ARGO_ROLLOUTS_VERSION}
ENV
}

prepare_inputs() {
  download_repo_archive "${KADM_SYSTEM_REPO}" "${KADM_SYSTEM_REF}"
  download_repo_archive "${KADM_RELEASE_CONSOLE_REPO}" "${KADM_RELEASE_CONSOLE_REF}"
  download_repo_archive "${KADM_APP_CONFIGS_REPO}" "${KADM_APP_CONFIGS_REF}"
}

prepare_runtime_manifests() {
  download "${ARGO_CD_URL}" "$(manifest_path "${ARGO_CD_URL}")"
  download "${ARGO_ROLLOUTS_URL}" "$(manifest_path "${ARGO_ROLLOUTS_URL}")"
}

prepare_bundle_assets() {
  download "${GATEWAY_API_URL}" "$(manifest_path "${GATEWAY_API_URL}")"
  download "${CILIUM_CHART_URL}" "${CHART_DIR}/cilium-${CILIUM_VERSION}.tgz"
  download "${K3S_INSTALL_SCRIPT_URL}" "${K3S_DIR}/install-${K3S_VERSION}.sh"
  download "${K3S_BINARY_URL}" "${K3S_DIR}/k3s-${K3S_VERSION}"
  download "${K3S_AIRGAP_IMAGES_URL}" "${K3S_DIR}/k3s-airgap-images-${K3S_VERSION}-${K3S_ARCH}.tar.zst"
  download "${HELM_URL}" "${TOOL_DIR}/helm-${HELM_VERSION}-${HELM_PLATFORM}.tar.gz"
}

prepare_inputs
prepare_runtime_manifests
write_runtime_image_list "${IMAGE_DIR}/runtime-images.txt"

if [[ "${LIST_IMAGES_ONLY}" -eq 1 ]]; then
  cat "${IMAGE_DIR}/runtime-images.txt"
  exit 0
fi

prepare_bundle_assets
if [[ "${SKIP_IMAGE_EXPORT}" -eq 1 ]]; then
  OFFLINE_COMPLETE=false
  : > "${IMAGE_DIR}/runtime-images.tar.zst"
else
  export_runtime_images "${IMAGE_DIR}/runtime-images.txt"
fi
write_metadata
write_checksums

BUNDLE_NAME="kadm-platform-assets-k3s-${K3S_VERSION}-gateway-${GATEWAY_API_VERSION}-argocd-${ARGO_CD_VERSION}-rollouts-${ARGO_ROLLOUTS_VERSION}-cilium-${CILIUM_VERSION}.tgz"
tar -czf "${DIST_DIR}/${BUNDLE_NAME}" -C "${DIST_DIR}" \
  metadata \
  cache/repos \
  cache/manifests \
  cache/charts \
  cache/k3s \
  cache/tools \
  cache/images
cp "${DIST_DIR}/${BUNDLE_NAME}" "${DIST_DIR}/kadm-platform-assets.tgz"

bundle_size="$(wc -c < "${DIST_DIR}/${BUNDLE_NAME}" | tr -d ' ')"
echo "bundle written: ${DIST_DIR}/${BUNDLE_NAME}"
echo "bundle size bytes: ${bundle_size}"
if (( bundle_size > BUNDLE_WARN_BYTES )); then
  echo "warning: bundle exceeds ${BUNDLE_WARN_BYTES} bytes; monitor GitHub Actions storage and release upload time" >&2
fi
if (( bundle_size > BUNDLE_SPLIT_BYTES )); then
  echo "warning: bundle exceeds split threshold ${BUNDLE_SPLIT_BYTES} bytes; publish as numbered parts" >&2
fi
