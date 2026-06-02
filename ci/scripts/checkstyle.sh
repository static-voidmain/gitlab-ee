#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Checkstyle 결과를 MR 댓글로 제공한다.
# 구현상세: Maven 프로젝트는 checkstyle 플러그인으로 XML을 생성하고 violation 수를 계산한다.

config="${CHECKSTYLE_CONFIG:-ci/checkstyle/company-checkstyle.xml}"
summary_file="${CHECKSTYLE_SUMMARY_FILE:-checkstyle-summary.txt}"
result_file="${CHECKSTYLE_RESULT_FILE:-target/checkstyle-result.xml}"
maven_opts="${MAVEN_CLI_OPTS:--B -ntp}"
read -r -a maven_cli_opts <<<"${maven_opts}"

if [[ ! -f "${config}" ]]; then
  echo "ERROR: Checkstyle config not found: ${config}" >&2
  exit 1
fi

mkdir -p "$(dirname "${result_file}")"

if [[ -f pom.xml ]]; then
  mvn "${maven_cli_opts[@]}" \
    -Dcheckstyle.config.location="${config}" \
    -Dcheckstyle.output.file="${result_file}" \
    checkstyle:checkstyle
else
  checkstyle_jar="${CHECKSTYLE_JAR:-}"
  if [[ -z "${checkstyle_jar}" || ! -f "${checkstyle_jar}" ]]; then
    echo "ERROR: pom.xml or CHECKSTYLE_JAR is required." >&2
    exit 1
  fi
  java -jar "${checkstyle_jar}" -c "${config}" -f xml -o "${result_file}" "${CHECKSTYLE_TARGET:-src}"
fi

violations="$(grep -c '<error ' "${result_file}" || true)"
{
  echo "Checkstyle result"
  echo "Violations: ${violations}"
  echo "Report: ${result_file}"
} >"${summary_file}"

bash ci/scripts/mr-comment.sh checkstyle "${summary_file}" "Checkstyle"

if [[ "${violations}" -gt 0 ]]; then
  exit 1
fi
