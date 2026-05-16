#!/usr/bin/env bash
set -Eeuo pipefail

# 테스트 통과: Docker 이미지의 CRITICAL/HIGH 취약점 결과를 도출한다.
# 보안제약: 스캐너 자체는 digest-pinned 내부 registry 이미지만 허용한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

TRIVY_IMAGE_REF="${TRIVY_IMAGE_REF:-}"
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-./runtime/trivy-cache}"
TRIVY_REPORT_DIR="${TRIVY_REPORT_DIR:-./reports/trivy}"

if [[ -z "${TRIVY_IMAGE_REF}" || "${TRIVY_IMAGE_REF}" != *@sha256:* || "${TRIVY_IMAGE_REF}" == *REPLACE_WITH_VERIFIED_DIGEST* ]]; then
  echo "ERROR: TRIVY_IMAGE_REF must be a digest-pinned, internally verified scanner image." >&2
  exit 1
fi

mkdir -p "${TRIVY_CACHE_DIR}" "${TRIVY_REPORT_DIR}"
TRIVY_CACHE_DIR_ABS="$(cd "${TRIVY_CACHE_DIR}" && pwd)"
TRIVY_REPORT_DIR_ABS="$(cd "${TRIVY_REPORT_DIR}" && pwd)"

images=(
  "${GITLAB_IMAGE:-gitlab/gitlab-ee:18.11.3-ee.0}"
  "${GITLAB_RUNNER_IMAGE:-gitlab/gitlab-runner:alpine-v18.11.2}"
  "${GITLAB_DOCS_IMAGE:-registry.gitlab.com/gitlab-org/technical-writing/docs-gitlab-com/archives:18.11}"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/jdk:8"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/jdk:17"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/jdk:21"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/maven:jdk8"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/maven:jdk17"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/maven:jdk21"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/gradle:jdk8"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/gradle:jdk17"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/gradle:jdk21"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/node:24"
  "${INTERNAL_IMAGE_REGISTRY:-registry.example.co.kr/scm-runners}/shell-tools:2026.05"
)

for image in "${images[@]}"; do
  safe_name="$(printf '%s' "${image}" | tr '/:@' '___')"
  report="${TRIVY_REPORT_DIR}/${safe_name}.txt"
  echo "Scanning ${image}"
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${TRIVY_CACHE_DIR_ABS}:/root/.cache" \
    -v "${TRIVY_REPORT_DIR_ABS}:/reports" \
    "${TRIVY_IMAGE_REF}" image \
      --platform linux/amd64 \
      --severity CRITICAL,HIGH \
      --ignore-unfixed \
      --exit-code 1 \
      --format table \
      --output "/reports/$(basename "${report}")" \
      "${image}"
done

echo "Image vulnerability scans completed. Reports: ${TRIVY_REPORT_DIR}"
