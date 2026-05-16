#!/usr/bin/env bash
set -Eeuo pipefail

# 구현상세: MR 댓글은 marker 기반으로 이전 댓글을 삭제 후 재작성한다.
# 제약사항: CI_JOB_TOKEN은 MR notes 권한이 제한될 수 있어 masked project/group token 사용을 권장한다.

comment_type="${1:?comment type is required}"
summary_file="${2:?summary file path is required}"
title="${3:-GitLab Quality Report}"

if [[ -z "${CI_MERGE_REQUEST_IID:-}" ]]; then
  echo "No merge request context. Skipping MR comment."
  exit 0
fi

if [[ ! -f "${summary_file}" ]]; then
  echo "ERROR: Summary file not found: ${summary_file}" >&2
  exit 1
fi

token="${GITLAB_MR_COMMENT_TOKEN:-${PRIVATE_TOKEN:-}}"
if [[ -z "${token}" ]]; then
  echo "ERROR: GITLAB_MR_COMMENT_TOKEN masked CI variable is required for MR comments." >&2
  exit 1
fi

for bin in curl jq; do
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "ERROR: ${bin} is required." >&2
    exit 1
  fi
done

api="${CI_API_V4_URL:?CI_API_V4_URL is required}"
project_id="${CI_PROJECT_ID:?CI_PROJECT_ID is required}"
mr_iid="${CI_MERGE_REQUEST_IID:?CI_MERGE_REQUEST_IID is required}"
marker="<!-- gitlab-ee-secure-bootstrap:${comment_type} -->"
max_bytes="${MR_COMMENT_MAX_BYTES:-60000}"

summary="$(head -c "${max_bytes}" "${summary_file}")"
body="${marker}

### ${title}

\`\`\`text
${summary}
\`\`\`"

notes_url="${api}/projects/${project_id}/merge_requests/${mr_iid}/notes"

existing_notes="$(curl --fail --silent --show-error \
  --header "PRIVATE-TOKEN: ${token}" \
  "${notes_url}?per_page=100")"

jq -r --arg marker "${marker}" '.[] | select(.body | contains($marker)) | .id' <<<"${existing_notes}" |
while read -r note_id; do
  [[ -z "${note_id}" ]] && continue
  curl --fail --silent --show-error \
    --request DELETE \
    --header "PRIVATE-TOKEN: ${token}" \
    "${notes_url}/${note_id}" >/dev/null
done

payload="$(jq -n --arg body "${body}" '{body: $body}')"
curl --fail --silent --show-error \
  --request POST \
  --header "PRIVATE-TOKEN: ${token}" \
  --header "Content-Type: application/json" \
  --data "${payload}" \
  "${notes_url}" >/dev/null

echo "MR comment updated: ${comment_type}"
