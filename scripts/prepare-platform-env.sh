#!/usr/bin/env bash
set -Eeuo pipefail

# macOS, Windows Git Bash/WSL, Linux에서 같은 방식으로 .env를 생성한다.
# GitLab EE 본체는 multi-arch 이미지이므로 host Docker 아키텍처와 같은 platform을 명시해 QEMU 재시작 루프를 피한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/prepare-platform-env.sh [default|vmware-2c6g] [--force]

Examples:
  ./scripts/prepare-platform-env.sh vmware-2c6g --force
  ./scripts/prepare-platform-env.sh default --force

USAGE
}

profile="${1:-vmware-2c6g}"
force=false

if [[ "${profile}" == "-h" || "${profile}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${profile}" == "--force" ]]; then
  profile="vmware-2c6g"
  force=true
fi

if [[ "${2:-}" == "--force" ]]; then
  force=true
elif [[ -n "${2:-}" ]]; then
  usage >&2
  exit 1
fi

case "${profile}" in
  default | production)
    source_file=".env.example"
    profile_label="default"
    ;;
  vmware-2c6g | vmware_2c_6g)
    source_file=".env.vmware-2c6g.example"
    profile_label="vmware-2c6g"
    ;;
  *)
    echo "ERROR: Unsupported profile: ${profile}" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ ! -f "${source_file}" ]]; then
  echo "ERROR: ${source_file} was not found." >&2
  exit 1
fi

normalize_platform() {
  raw_arch="$1"
  normalized_arch="$(printf '%s' "${raw_arch}" | tr '[:upper:]' '[:lower:]')"

  case "${normalized_arch}" in
    amd64 | x86_64)
      printf '%s\n' "linux/amd64"
      ;;
    arm64 | aarch64)
      printf '%s\n' "linux/arm64"
      ;;
    *)
      return 1
      ;;
  esac
}

detect_gitlab_platform() {
  docker_arch=""
  if command -v docker >/dev/null 2>&1; then
    docker_arch="$(docker info --format '{{.Architecture}}' 2>/dev/null || true)"
  fi

  if [[ -n "${docker_arch}" ]] && normalize_platform "${docker_arch}" >/dev/null 2>&1; then
    normalize_platform "${docker_arch}"
    return 0
  fi

  uname_arch="$(uname -m 2>/dev/null || true)"
  if [[ -n "${uname_arch}" ]] && normalize_platform "${uname_arch}" >/dev/null 2>&1; then
    normalize_platform "${uname_arch}"
    return 0
  fi

  echo "ERROR: Could not detect host architecture. Set GITLAB_PLATFORM manually to linux/amd64 or linux/arm64." >&2
  return 1
}

gitlab_platform="$(detect_gitlab_platform)"

if [[ -f ".env" && "${force}" != true ]]; then
  echo "ERROR: .env already exists. Re-run with --force after reviewing the current file." >&2
  exit 1
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/gitlab-ee-env.XXXXXX")"
trap 'rm -f "${tmp_file}"' EXIT

platform_written=false
while IFS= read -r line || [[ -n "${line}" ]]; do
  case "${line}" in
    GITLAB_ENV_FILE=*)
      printf 'GITLAB_ENV_FILE=.env\n' >>"${tmp_file}"
      ;;
    GITLAB_PLATFORM=*)
      printf 'GITLAB_PLATFORM=%s\n' "${gitlab_platform}" >>"${tmp_file}"
      platform_written=true
      ;;
    *)
      printf '%s\n' "${line}" >>"${tmp_file}"
      ;;
  esac
done <"${source_file}"

if [[ "${platform_written}" != true ]]; then
  {
    printf '\n'
    printf 'GITLAB_PLATFORM=%s\n' "${gitlab_platform}"
  } >>"${tmp_file}"
fi

mv "${tmp_file}" ".env"
trap - EXIT

echo "Generated .env from ${source_file}"
echo "Profile: ${profile_label}"
echo "GitLab EE platform: ${gitlab_platform}"

if [[ "${profile_label}" == "vmware-2c6g" ]]; then
  echo "Next: docker compose --env-file .env -f docker-compose.yml -f docker-compose.vmware-2c6g.yml config"
else
  echo "Next: docker compose --env-file .env config"
fi
