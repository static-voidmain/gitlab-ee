#!/usr/bin/env bash
set -Eeuo pipefail

# 운영: 실제 restore 전에 백업 파일 무결성을 빠르게 확인한다.
# 구현상세: destructive restore를 수행하지 않고 tar 목록과 checksum만 검증한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

BACKUP_DIR="${GITLAB_HOME:-/srv/gitlab-ee}/backups"
LATEST_BACKUP="$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -print 2>/dev/null | sort | tail -n 1)"

if [[ -z "${LATEST_BACKUP}" ]]; then
  echo "ERROR: No GitLab backup tar found in ${BACKUP_DIR}." >&2
  exit 1
fi

echo "Checking backup: ${LATEST_BACKUP}"
tar -tf "${LATEST_BACKUP}" >/dev/null

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${LATEST_BACKUP}"
else
  shasum -a 256 "${LATEST_BACKUP}"
fi

echo "Backup archive is readable."
