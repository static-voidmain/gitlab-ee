#!/usr/bin/env bash
set -Eeuo pipefail

# 요구사항: Coverage 결과를 GitLab MR widget/report와 MR 댓글에 동시에 제공한다.
# 구현상세: JaCoCo XML의 INSTRUCTION counter를 집계해 GitLab coverage regex에 맞는 라인을 출력한다.

jacoco_xml="${JACOCO_XML:-target/site/jacoco/jacoco.xml}"
summary_file="${COVERAGE_SUMMARY_FILE:-coverage-summary.txt}"
maven_opts="${MAVEN_CLI_OPTS:--B -ntp}"

if [[ -f pom.xml ]]; then
  mvn ${maven_opts} test jacoco:report
fi

if [[ ! -f "${jacoco_xml}" ]]; then
  echo "ERROR: JaCoCo XML not found: ${jacoco_xml}" >&2
  exit 1
fi

coverage="$(awk -F'"' '
  /<counter type="INSTRUCTION"/ {
    for (i = 1; i <= NF; i++) {
      if ($i == " missed=") missed = $(i + 1)
      if ($i == " covered=") covered = $(i + 1)
    }
  }
  END {
    total = missed + covered
    if (total == 0) {
      print "0.00"
    } else {
      printf "%.2f", (covered * 100) / total
    }
  }
' "${jacoco_xml}")"

{
  echo "Coverage result"
  echo "Total coverage: ${coverage}%"
  echo "Report: ${jacoco_xml}"
} | tee "${summary_file}"

bash ci/scripts/mr-comment.sh coverage "${summary_file}" "Code Coverage"
