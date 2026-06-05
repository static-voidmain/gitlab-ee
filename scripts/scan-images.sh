#!/usr/bin/env bash
set -Eeuo pipefail

# 테스트 통과: docker scout quickview 요약과 Critical/High CVE 상세 결과를 도출한다.
# 보안제약: amd64 결과만 검사하고 하나라도 Critical/High가 있으면 최종 실패한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

SCOUT_IMAGE_PREFIX="${SCOUT_IMAGE_PREFIX:-image://}"
SCOUT_REPORT_DIR="${SCOUT_REPORT_DIR:-./reports/docker-scout}"
LOCAL_IMAGE_NAMESPACE="${LOCAL_IMAGE_NAMESPACE:-bwc}"
include_legacy=false
include_shell_tools=false
requested_images=()

for arg in "$@"; do
  case "${arg}" in
    --include-legacy) include_legacy=true ;;
    --include-shell-tools) include_shell_tools=true ;;
    --) ;;
    -*) echo "ERROR: Unsupported option: ${arg}" >&2; exit 1 ;;
    *) requested_images+=("${arg}") ;;
  esac
done

case "${SCOUT_IMAGE_PREFIX}" in
  image://|local://|registry://) ;;
  *) echo "ERROR: SCOUT_IMAGE_PREFIX must be image://, local://, or registry://." >&2; exit 1 ;;
esac

if ! command -v docker >/dev/null 2>&1 || ! docker scout version >/dev/null 2>&1; then
  echo "ERROR: Docker Scout CLI is required. Install Docker Scout and authenticate with docker login." >&2
  exit 1
fi

mkdir -p "${SCOUT_REPORT_DIR}"
summary_report="${SCOUT_REPORT_DIR}/summary.tsv"
: >"${summary_report}"
printf 'image\tstatus\tquickview_report\tcve_report\n' >>"${summary_report}"

if [[ "${#requested_images[@]}" -gt 0 ]]; then
  images=("${requested_images[@]}")
else
  images=(
    "${GITLAB_IMAGE:-gitlab/gitlab-ee:19.0.0-ee.0}"
    "${GITLAB_RUNNER_IMAGE:-gitlab/gitlab-runner:alpine-v19.0.0}"
    "${GITLAB_DOCS_IMAGE:-registry.gitlab.com/gitlab-org/technical-writing/docs-gitlab-com/archives:19.0}"
    "${GITLAB_SHELL_RUNNER_IMAGE:-${LOCAL_IMAGE_NAMESPACE}/gitlab-runner-shell:19.0.0}"
    "${LOCAL_IMAGE_NAMESPACE}/jdk:8"
    "${LOCAL_IMAGE_NAMESPACE}/jdk:17"
    "${LOCAL_IMAGE_NAMESPACE}/jdk:21"
    "${LOCAL_IMAGE_NAMESPACE}/maven:jdk8"
    "${LOCAL_IMAGE_NAMESPACE}/maven:jdk17"
    "${LOCAL_IMAGE_NAMESPACE}/maven:jdk21"
    "${LOCAL_IMAGE_NAMESPACE}/gradle:jdk8"
    "${LOCAL_IMAGE_NAMESPACE}/gradle:jdk17"
    "${LOCAL_IMAGE_NAMESPACE}/gradle:jdk21"
    "${LOCAL_IMAGE_NAMESPACE}/node:24"
  )
fi

if [[ "${include_shell_tools}" == true ]]; then
  images+=("${LOCAL_IMAGE_NAMESPACE}/shell-tools:2026.06")
fi

if [[ "${include_legacy}" == true ]]; then
  images+=(
    "${LOCAL_IMAGE_NAMESPACE}/jdk:7"
    "${LOCAL_IMAGE_NAMESPACE}/maven:jdk7"
    "${LOCAL_IMAGE_NAMESPACE}/gradle:jdk7"
  )
fi

overall_status=0
for image in "${images[@]}"; do
  if [[ "${image}" == *://* ]]; then
    artifact_ref="${image}"
  else
    artifact_ref="${SCOUT_IMAGE_PREFIX}${image}"
  fi

  safe_name="$(printf '%s' "${image}" | tr '/:@' '____')"
  quickview_report="${SCOUT_REPORT_DIR}/${safe_name}.quickview.txt"
  cve_report="${SCOUT_REPORT_DIR}/${safe_name}.critical-high.txt"

  echo "Scanning ${artifact_ref}"
  if ! docker scout quickview \
    --platform linux/amd64 \
    --output "${quickview_report}" \
    "${artifact_ref}"; then
    printf '%s\tSCAN_ERROR\t%s\t%s\n' "${image}" "${quickview_report}" "${cve_report}" >>"${summary_report}"
    overall_status=1
    continue
  fi

  set +e
  docker scout cves \
    --platform linux/amd64 \
    --only-severity critical,high \
    --exit-code \
    --output "${cve_report}" \
    "${artifact_ref}"
  cve_status=$?
  set -e

  case "${cve_status}" in
    0) scan_status="PASS" ;;
    2) scan_status="CRITICAL_OR_HIGH_FOUND"; overall_status=1 ;;
    *) scan_status="SCAN_ERROR"; overall_status=1 ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "${image}" "${scan_status}" "${quickview_report}" "${cve_report}" >>"${summary_report}"
done

cat "${summary_report}"
echo "Docker Scout image scans completed. Reports: ${SCOUT_REPORT_DIR}"
exit "${overall_status}"
