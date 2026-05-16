#!/usr/bin/env bash
set -Eeuo pipefail

# 운영: GitLab application data와 /etc/gitlab 설정 백업을 표준화한다.
# 제약사항: 백업 파일은 권한과 저장소 암호화 정책을 별도로 적용해야 한다.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

echo "Creating GitLab application backup..."
docker compose exec -T gitlab gitlab-backup create CRON=1

echo "Creating GitLab configuration backup..."
docker compose exec -T gitlab gitlab-ctl backup-etc

echo "Backup completed. Review ${GITLAB_HOME:-/srv/gitlab-ee}/backups and ${GITLAB_HOME:-/srv/gitlab-ee}/config/config_backup."
