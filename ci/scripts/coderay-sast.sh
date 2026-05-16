#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Shell runner에서 사내 CodeRay 6.0 RG CLI로 secure code check를 요청한다.
# 구현상세: 사내 CLI 명령 형태를 단정하지 않고 CODERAY_CLI_ARGS로 운영 환경에서 명시하게 한다.

summary_file="${CODERAY_SUMMARY_FILE:-coderay-summary.txt}"
log_file="${CODERAY_LOG_FILE:-coderay-cli.log}"
coderay_cli="${CODERAY_CLI:-/opt/coderay/coderay}"

if [[ ! -x "${coderay_cli}" ]]; then
  {
    echo "CodeRay CLI is not executable: ${coderay_cli}"
    echo "Mount CODERAY_CLI_DIR and set CODERAY_CLI if the binary name differs."
  } >"${summary_file}"
  bash ci/scripts/mr-comment.sh coderay "${summary_file}" "CodeRay SAST" || true
  exit 1
fi

if [[ -z "${CODERAY_CLI_ARGS:-}" ]]; then
  {
    echo "CODERAY_CLI_ARGS is required."
    echo "Example: CODERAY_CLI_ARGS='--project ${CI_PROJECT_PATH:-project} --source . --summary ${summary_file}'"
    echo "The exact options must match the internal CodeRay 6.0 RG CLI contract."
  } >"${summary_file}"
  bash ci/scripts/mr-comment.sh coderay "${summary_file}" "CodeRay SAST" || true
  exit 1
fi

set +e
# shellcheck disable=SC2086
"${coderay_cli}" ${CODERAY_CLI_ARGS} >"${log_file}" 2>&1
status=$?
set -e

if [[ ! -s "${summary_file}" ]]; then
  cp "${log_file}" "${summary_file}"
fi

bash ci/scripts/mr-comment.sh coderay "${summary_file}" "CodeRay SAST"
exit "${status}"
